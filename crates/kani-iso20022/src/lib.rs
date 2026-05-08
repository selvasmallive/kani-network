use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum Iso20022Error {
    #[error("unsupported ISO 20022 message type: {0}")]
    UnsupportedMessageType(String),
    #[error("message body is empty")]
    EmptyMessage,
    #[error("invalid XML: {0}")]
    InvalidXml(String),
    #[error("pacs.008 field {0} is required")]
    MissingField(&'static str),
    #[error("pacs.008 requires exactly one CdtTrfTxInf transaction, got {0}")]
    UnsupportedTransactionCount(usize),
    #[error("pacs.008 amount must be a positive integer in minor units")]
    InvalidAmount,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum IsoMessageType {
    #[serde(rename = "pacs.008")]
    Pacs008,
    #[serde(rename = "pacs.002")]
    Pacs002,
    #[serde(rename = "camt")]
    Camt,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct IsoEnvelope {
    pub message_type: IsoMessageType,
    pub raw_xml: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Pacs008CreditTransfer {
    pub message_id: String,
    pub instruction_id: Option<String>,
    pub end_to_end_id: String,
    pub debtor_account: String,
    pub creditor_account: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum Pacs002TransactionStatus {
    AcceptedSettlementCompleted,
    AcceptedSettlementInProcess,
    Rejected,
}

impl Pacs002TransactionStatus {
    pub fn code(self) -> &'static str {
        match self {
            Self::AcceptedSettlementCompleted => "ACSC",
            Self::AcceptedSettlementInProcess => "ACSP",
            Self::Rejected => "RJCT",
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Pacs002PaymentStatus {
    pub message_id: String,
    pub created_at: String,
    pub original_message_id: String,
    pub original_message_name_id: String,
    pub original_instruction_id: String,
    pub original_end_to_end_id: String,
    pub transaction_id: String,
    pub status: Pacs002TransactionStatus,
    pub status_reason: Option<String>,
    pub asset: String,
    pub amount: i128,
    pub debtor_account: String,
    pub creditor_account: String,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum Camt053CreditDebitIndicator {
    Credit,
    Debit,
}

impl Camt053CreditDebitIndicator {
    pub fn code(self) -> &'static str {
        match self {
            Self::Credit => "CRDT",
            Self::Debit => "DBIT",
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Camt053Entry {
    pub id: String,
    pub transaction_id: String,
    pub asset: String,
    pub amount: i128,
    pub direction: Camt053CreditDebitIndicator,
    pub block_height: i64,
    pub booked_at: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Camt053Statement {
    pub message_id: String,
    pub created_at: String,
    pub statement_id: String,
    pub account_id: String,
    pub asset: String,
    pub balance: i128,
    pub entries: Vec<Camt053Entry>,
}

pub fn parse_envelope(
    message_type: &str,
    raw_xml: impl Into<String>,
) -> Result<IsoEnvelope, Iso20022Error> {
    let raw_xml = raw_xml.into();
    if raw_xml.trim().is_empty() {
        return Err(Iso20022Error::EmptyMessage);
    }

    let message_type = match message_type {
        "pacs.008" => IsoMessageType::Pacs008,
        "pacs.002" => IsoMessageType::Pacs002,
        "camt" | "camt.*" => IsoMessageType::Camt,
        other => return Err(Iso20022Error::UnsupportedMessageType(other.to_string())),
    };

    Ok(IsoEnvelope {
        message_type,
        raw_xml,
    })
}

pub fn parse_pacs008_credit_transfer(
    raw_xml: impl AsRef<str>,
) -> Result<Pacs008CreditTransfer, Iso20022Error> {
    let raw_xml = raw_xml.as_ref();
    if raw_xml.trim().is_empty() {
        return Err(Iso20022Error::EmptyMessage);
    }

    let document = roxmltree::Document::parse(raw_xml)
        .map_err(|error| Iso20022Error::InvalidXml(error.to_string()))?;

    let message_id = required_child_text(
        &document.root_element(),
        &["FIToFICstmrCdtTrf", "GrpHdr", "MsgId"],
        "GrpHdr/MsgId",
    )?;

    let transactions: Vec<_> = document
        .descendants()
        .filter(|node| node.is_element() && node.tag_name().name() == "CdtTrfTxInf")
        .collect();

    if transactions.len() != 1 {
        return Err(Iso20022Error::UnsupportedTransactionCount(
            transactions.len(),
        ));
    }

    let transaction = transactions[0];
    let instruction_id = child_text(&transaction, &["PmtId", "InstrId"]);
    let end_to_end_id =
        required_child_text(&transaction, &["PmtId", "EndToEndId"], "PmtId/EndToEndId")?;
    let amount_node = first_child(&transaction, &["IntrBkSttlmAmt"])
        .or_else(|| first_child(&transaction, &["InstdAmt"]))
        .ok_or(Iso20022Error::MissingField("IntrBkSttlmAmt"))?;
    let asset = amount_node
        .attribute("Ccy")
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or(Iso20022Error::MissingField("IntrBkSttlmAmt/@Ccy"))?
        .to_string();
    let amount = parse_minor_units(amount_node.text().unwrap_or_default())?;
    let debtor_account = child_text(&transaction, &["DbtrAcct", "Id", "Othr", "Id"])
        .or_else(|| child_text(&transaction, &["Dbtr", "Id", "OrgId", "Othr", "Id"]))
        .ok_or(Iso20022Error::MissingField("DbtrAcct/Id/Othr/Id"))?;
    let creditor_account = child_text(&transaction, &["CdtrAcct", "Id", "Othr", "Id"])
        .or_else(|| child_text(&transaction, &["Cdtr", "Id", "OrgId", "Othr", "Id"]))
        .ok_or(Iso20022Error::MissingField("CdtrAcct/Id/Othr/Id"))?;

    Ok(Pacs008CreditTransfer {
        message_id,
        instruction_id,
        end_to_end_id,
        debtor_account,
        creditor_account,
        asset,
        amount,
    })
}

pub fn build_pacs002_status_report(status: &Pacs002PaymentStatus) -> String {
    let mut xml = String::new();
    xml.push_str(r#"<?xml version="1.0" encoding="UTF-8"?>"#);
    xml.push('\n');
    xml.push_str(r#"<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.10">"#);
    xml.push('\n');
    xml.push_str("  <FIToFIPmtStsRpt>\n");
    xml.push_str("    <GrpHdr>\n");
    push_element(&mut xml, 6, "MsgId", &status.message_id);
    push_element(&mut xml, 6, "CreDtTm", &status.created_at);
    xml.push_str("    </GrpHdr>\n");
    xml.push_str("    <OrgnlGrpInfAndSts>\n");
    push_element(&mut xml, 6, "OrgnlMsgId", &status.original_message_id);
    push_element(
        &mut xml,
        6,
        "OrgnlMsgNmId",
        &status.original_message_name_id,
    );
    xml.push_str("    </OrgnlGrpInfAndSts>\n");
    xml.push_str("    <TxInfAndSts>\n");
    push_element(&mut xml, 6, "OrgnlInstrId", &status.original_instruction_id);
    push_element(
        &mut xml,
        6,
        "OrgnlEndToEndId",
        &status.original_end_to_end_id,
    );
    push_element(&mut xml, 6, "TxId", &status.transaction_id);
    push_element(&mut xml, 6, "TxSts", status.status.code());
    if let Some(reason) = status
        .status_reason
        .as_deref()
        .map(str::trim)
        .filter(|reason| !reason.is_empty())
    {
        xml.push_str("      <StsRsnInf>\n");
        xml.push_str("        <Rsn>\n");
        push_element(&mut xml, 10, "Prtry", "KANI_SANDBOX");
        xml.push_str("        </Rsn>\n");
        push_element(&mut xml, 8, "AddtlInf", reason);
        xml.push_str("      </StsRsnInf>\n");
    }
    xml.push_str("      <OrgnlTxRef>\n");
    push_amount_element(&mut xml, 8, "IntrBkSttlmAmt", &status.asset, status.amount);
    xml.push_str("        <DbtrAcct>\n");
    xml.push_str("          <Id>\n");
    xml.push_str("            <Othr>\n");
    push_element(&mut xml, 14, "Id", &status.debtor_account);
    xml.push_str("            </Othr>\n");
    xml.push_str("          </Id>\n");
    xml.push_str("        </DbtrAcct>\n");
    xml.push_str("        <CdtrAcct>\n");
    xml.push_str("          <Id>\n");
    xml.push_str("            <Othr>\n");
    push_element(&mut xml, 14, "Id", &status.creditor_account);
    xml.push_str("            </Othr>\n");
    xml.push_str("          </Id>\n");
    xml.push_str("        </CdtrAcct>\n");
    xml.push_str("      </OrgnlTxRef>\n");
    xml.push_str("    </TxInfAndSts>\n");
    xml.push_str("  </FIToFIPmtStsRpt>\n");
    xml.push_str("</Document>\n");
    xml
}

pub fn build_camt053_statement(statement: &Camt053Statement) -> String {
    let mut xml = String::new();
    xml.push_str(r#"<?xml version="1.0" encoding="UTF-8"?>"#);
    xml.push('\n');
    xml.push_str(r#"<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">"#);
    xml.push('\n');
    xml.push_str("  <BkToCstmrStmt>\n");
    xml.push_str("    <GrpHdr>\n");
    push_element(&mut xml, 6, "MsgId", &statement.message_id);
    push_element(&mut xml, 6, "CreDtTm", &statement.created_at);
    xml.push_str("    </GrpHdr>\n");
    xml.push_str("    <Stmt>\n");
    push_element(&mut xml, 6, "Id", &statement.statement_id);
    push_element(&mut xml, 6, "ElctrncSeqNb", "1");
    xml.push_str("      <Acct>\n");
    xml.push_str("        <Id>\n");
    xml.push_str("          <Othr>\n");
    push_element(&mut xml, 12, "Id", &statement.account_id);
    xml.push_str("          </Othr>\n");
    xml.push_str("        </Id>\n");
    push_element(&mut xml, 8, "Ccy", &statement.asset);
    xml.push_str("      </Acct>\n");
    xml.push_str("      <Bal>\n");
    xml.push_str("        <Tp>\n");
    xml.push_str("          <CdOrPrtry>\n");
    push_element(&mut xml, 12, "Cd", "CLBD");
    xml.push_str("          </CdOrPrtry>\n");
    xml.push_str("        </Tp>\n");
    push_amount_element(
        &mut xml,
        8,
        "Amt",
        &statement.asset,
        positive_amount(statement.balance),
    );
    push_element(
        &mut xml,
        8,
        "CdtDbtInd",
        balance_credit_debit_indicator(statement.balance).code(),
    );
    xml.push_str("        <Dt>\n");
    push_element(&mut xml, 10, "DtTm", &statement.created_at);
    xml.push_str("        </Dt>\n");
    xml.push_str("      </Bal>\n");

    for entry in &statement.entries {
        xml.push_str("      <Ntry>\n");
        push_element(&mut xml, 8, "NtryRef", &entry.id);
        push_amount_element(
            &mut xml,
            8,
            "Amt",
            &entry.asset,
            positive_amount(entry.amount),
        );
        push_element(&mut xml, 8, "CdtDbtInd", entry.direction.code());
        xml.push_str("        <Sts>\n");
        push_element(&mut xml, 10, "Cd", "BOOK");
        xml.push_str("        </Sts>\n");
        xml.push_str("        <BookgDt>\n");
        push_element(&mut xml, 10, "DtTm", &entry.booked_at);
        xml.push_str("        </BookgDt>\n");
        push_element(&mut xml, 8, "AcctSvcrRef", &entry.transaction_id);
        push_element(
            &mut xml,
            8,
            "AddtlNtryInf",
            &format!("KANI block_height={}", entry.block_height),
        );
        xml.push_str("      </Ntry>\n");
    }

    xml.push_str("    </Stmt>\n");
    xml.push_str("  </BkToCstmrStmt>\n");
    xml.push_str("</Document>\n");
    xml
}

fn required_child_text<'a, 'input>(
    node: &roxmltree::Node<'a, 'input>,
    path: &[&str],
    field_name: &'static str,
) -> Result<String, Iso20022Error> {
    child_text(node, path).ok_or(Iso20022Error::MissingField(field_name))
}

fn child_text<'a, 'input>(node: &roxmltree::Node<'a, 'input>, path: &[&str]) -> Option<String> {
    first_child(node, path).and_then(|node| {
        node.text()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned)
    })
}

fn first_child<'a, 'input>(
    node: &roxmltree::Node<'a, 'input>,
    path: &[&str],
) -> Option<roxmltree::Node<'a, 'input>> {
    let mut cursor = *node;
    for name in path {
        cursor = cursor
            .children()
            .find(|child| child.is_element() && child.tag_name().name() == *name)?;
    }
    Some(cursor)
}

fn parse_minor_units(value: &str) -> Result<i128, Iso20022Error> {
    let value = value.trim();
    if value.is_empty()
        || !value.chars().all(|character| character.is_ascii_digit())
        || value.starts_with('0') && value.len() > 1
    {
        return Err(Iso20022Error::InvalidAmount);
    }

    let amount = value
        .parse::<i128>()
        .map_err(|_| Iso20022Error::InvalidAmount)?;
    if amount <= 0 {
        return Err(Iso20022Error::InvalidAmount);
    }

    Ok(amount)
}

fn balance_credit_debit_indicator(balance: i128) -> Camt053CreditDebitIndicator {
    if balance < 0 {
        Camt053CreditDebitIndicator::Debit
    } else {
        Camt053CreditDebitIndicator::Credit
    }
}

fn positive_amount(amount: i128) -> i128 {
    amount.checked_abs().unwrap_or(i128::MAX)
}

fn push_element(xml: &mut String, indent: usize, name: &str, value: &str) {
    xml.push_str(&" ".repeat(indent));
    xml.push('<');
    xml.push_str(name);
    xml.push('>');
    xml.push_str(&escape_xml_text(value));
    xml.push_str("</");
    xml.push_str(name);
    xml.push_str(">\n");
}

fn push_amount_element(xml: &mut String, indent: usize, name: &str, asset: &str, amount: i128) {
    xml.push_str(&" ".repeat(indent));
    xml.push('<');
    xml.push_str(name);
    xml.push_str(r#" Ccy=""#);
    xml.push_str(&escape_xml_attribute(asset));
    xml.push_str(r#"">"#);
    xml.push_str(&amount.to_string());
    xml.push_str("</");
    xml.push_str(name);
    xml.push_str(">\n");
}

fn escape_xml_text(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn escape_xml_attribute(value: &str) -> String {
    escape_xml_text(value)
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

#[cfg(test)]
mod tests {
    use super::*;

    const PACS008: &str = r#"
        <Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
          <FIToFICstmrCdtTrf>
            <GrpHdr>
              <MsgId>msg-001</MsgId>
            </GrpHdr>
            <CdtTrfTxInf>
              <PmtId>
                <InstrId>instr-001</InstrId>
                <EndToEndId>e2e-001</EndToEndId>
              </PmtId>
              <IntrBkSttlmAmt Ccy="KCAD_TEST">100000</IntrBkSttlmAmt>
              <DbtrAcct>
                <Id>
                  <Othr>
                    <Id>CORP_A</Id>
                  </Othr>
                </Id>
              </DbtrAcct>
              <CdtrAcct>
                <Id>
                  <Othr>
                    <Id>CORP_B</Id>
                  </Othr>
                </Id>
              </CdtrAcct>
            </CdtTrfTxInf>
          </FIToFICstmrCdtTrf>
        </Document>
    "#;

    #[test]
    fn parses_namespaced_pacs008_credit_transfer() {
        let transfer = parse_pacs008_credit_transfer(PACS008).unwrap();

        assert_eq!(transfer.message_id, "msg-001");
        assert_eq!(transfer.instruction_id.as_deref(), Some("instr-001"));
        assert_eq!(transfer.end_to_end_id, "e2e-001");
        assert_eq!(transfer.debtor_account, "CORP_A");
        assert_eq!(transfer.creditor_account, "CORP_B");
        assert_eq!(transfer.asset, "KCAD_TEST");
        assert_eq!(transfer.amount, 100000);
    }

    #[test]
    fn rejects_multiple_credit_transfers_for_mvp() {
        let xml = PACS008.replace(
            "</FIToFICstmrCdtTrf>",
            "<CdtTrfTxInf /></FIToFICstmrCdtTrf>",
        );
        let error = parse_pacs008_credit_transfer(xml).unwrap_err();

        assert!(matches!(
            error,
            Iso20022Error::UnsupportedTransactionCount(2)
        ));
    }

    #[test]
    fn rejects_fractional_amounts() {
        let xml = PACS008.replace(">100000<", ">100.00<");
        let error = parse_pacs008_credit_transfer(xml).unwrap_err();

        assert!(matches!(error, Iso20022Error::InvalidAmount));
    }

    #[test]
    fn rejects_missing_accounts() {
        let xml = PACS008
            .replace("<DbtrAcct>", "<DbtrAcctMissing>")
            .replace("</DbtrAcct>", "</DbtrAcctMissing>");
        let error = parse_pacs008_credit_transfer(xml).unwrap_err();

        assert!(matches!(
            error,
            Iso20022Error::MissingField("DbtrAcct/Id/Othr/Id")
        ));
    }

    #[test]
    fn builds_pacs002_status_report_for_finalized_payment() {
        let status = Pacs002PaymentStatus {
            message_id: "pacs.002:payment-001".to_string(),
            created_at: "2026-05-07T10:00:00Z".to_string(),
            original_message_id: "pacs008-msg-001".to_string(),
            original_message_name_id: "pacs.008.001.08".to_string(),
            original_instruction_id: "payment-001".to_string(),
            original_end_to_end_id: "e2e-001".to_string(),
            transaction_id: "payment-001".to_string(),
            status: Pacs002TransactionStatus::AcceptedSettlementCompleted,
            status_reason: None,
            asset: "KCAD_TEST".to_string(),
            amount: 25000,
            debtor_account: "CORP_A".to_string(),
            creditor_account: "CORP_B".to_string(),
        };

        let xml = build_pacs002_status_report(&status);

        assert!(xml.contains("pacs.002.001.10"));
        assert!(xml.contains("<OrgnlMsgId>pacs008-msg-001</OrgnlMsgId>"));
        assert!(xml.contains("<OrgnlEndToEndId>e2e-001</OrgnlEndToEndId>"));
        assert!(xml.contains("<TxSts>ACSC</TxSts>"));
        assert!(xml.contains(r#"<IntrBkSttlmAmt Ccy="KCAD_TEST">25000</IntrBkSttlmAmt>"#));
    }

    #[test]
    fn pacs002_status_report_escapes_xml_values() {
        let status = Pacs002PaymentStatus {
            message_id: "pacs.002:<payment>&001".to_string(),
            created_at: "2026-05-07T10:00:00Z".to_string(),
            original_message_id: "msg&001".to_string(),
            original_message_name_id: "pacs.008.001.08".to_string(),
            original_instruction_id: "payment-001".to_string(),
            original_end_to_end_id: "e2e-001".to_string(),
            transaction_id: "payment-001".to_string(),
            status: Pacs002TransactionStatus::Rejected,
            status_reason: Some("insufficient <funds> & rejected".to_string()),
            asset: "KCAD_\"TEST\"".to_string(),
            amount: 25000,
            debtor_account: "CORP_A".to_string(),
            creditor_account: "CORP_B".to_string(),
        };

        let xml = build_pacs002_status_report(&status);

        assert!(xml.contains("<MsgId>pacs.002:&lt;payment&gt;&amp;001</MsgId>"));
        assert!(xml.contains("<OrgnlMsgId>msg&amp;001</OrgnlMsgId>"));
        assert!(xml.contains("<TxSts>RJCT</TxSts>"));
        assert!(xml.contains("insufficient &lt;funds&gt; &amp; rejected"));
        assert!(xml.contains(r#"Ccy="KCAD_&quot;TEST&quot;""#));
    }

    #[test]
    fn builds_camt053_statement_with_credit_and_debit_entries() {
        let statement = Camt053Statement {
            message_id: "camt.053:CORP_A:KCAD_TEST:1".to_string(),
            created_at: "2026-05-07T10:00:00Z".to_string(),
            statement_id: "stmt:CORP_A:KCAD_TEST:1".to_string(),
            account_id: "CORP_A".to_string(),
            asset: "KCAD_TEST".to_string(),
            balance: 875000,
            entries: vec![
                Camt053Entry {
                    id: "journal-credit".to_string(),
                    transaction_id: "mint-tx".to_string(),
                    asset: "KCAD_TEST".to_string(),
                    amount: 1000000,
                    direction: Camt053CreditDebitIndicator::Credit,
                    block_height: 1,
                    booked_at: "2026-05-07T10:01:00Z".to_string(),
                },
                Camt053Entry {
                    id: "journal-debit".to_string(),
                    transaction_id: "transfer-tx".to_string(),
                    asset: "KCAD_TEST".to_string(),
                    amount: 125000,
                    direction: Camt053CreditDebitIndicator::Debit,
                    block_height: 2,
                    booked_at: "2026-05-07T10:02:00Z".to_string(),
                },
            ],
        };

        let xml = build_camt053_statement(&statement);

        assert!(xml.contains("camt.053.001.08"));
        assert!(xml.contains("<BkToCstmrStmt>"));
        assert!(xml.contains("<Id>CORP_A</Id>"));
        assert!(xml.contains("<Cd>CLBD</Cd>"));
        assert!(xml.contains(r#"<Amt Ccy="KCAD_TEST">875000</Amt>"#));
        assert!(xml.contains("<CdtDbtInd>CRDT</CdtDbtInd>"));
        assert!(xml.contains("<CdtDbtInd>DBIT</CdtDbtInd>"));
        assert!(xml.contains("<AcctSvcrRef>transfer-tx</AcctSvcrRef>"));
        assert!(xml.contains("<AddtlNtryInf>KANI block_height=2</AddtlNtryInf>"));
    }

    #[test]
    fn camt053_statement_escapes_xml_values() {
        let statement = Camt053Statement {
            message_id: "camt.053:<msg>&1".to_string(),
            created_at: "2026-05-07T10:00:00Z".to_string(),
            statement_id: "stmt:&1".to_string(),
            account_id: "CORP_<A>".to_string(),
            asset: "KCAD_\"TEST\"".to_string(),
            balance: 100,
            entries: vec![Camt053Entry {
                id: "entry&1".to_string(),
                transaction_id: "tx<1>".to_string(),
                asset: "KCAD_\"TEST\"".to_string(),
                amount: 100,
                direction: Camt053CreditDebitIndicator::Credit,
                block_height: 1,
                booked_at: "2026-05-07T10:01:00Z".to_string(),
            }],
        };

        let xml = build_camt053_statement(&statement);

        assert!(xml.contains("<MsgId>camt.053:&lt;msg&gt;&amp;1</MsgId>"));
        assert!(xml.contains("<Id>stmt:&amp;1</Id>"));
        assert!(xml.contains("<Id>CORP_&lt;A&gt;</Id>"));
        assert!(xml.contains("<NtryRef>entry&amp;1</NtryRef>"));
        assert!(xml.contains("<AcctSvcrRef>tx&lt;1&gt;</AcctSvcrRef>"));
        assert!(xml.contains(r#"Ccy="KCAD_&quot;TEST&quot;""#));
    }
}
