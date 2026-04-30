use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum Iso20022Error {
    #[error("unsupported ISO 20022 message type: {0}")]
    UnsupportedMessageType(String),
    #[error("message body is empty")]
    EmptyMessage,
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
