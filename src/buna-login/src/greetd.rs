//! Logging in through greetd: one call, `log_in`, holds the whole
//! conversation with the daemon over its socket ($GREETD_SOCK).
//!
//! The wire format is greetd's IPC: each message is a 4-byte length in the
//! machine's byte order, then that many bytes of JSON.  greetd answers every
//! request with success, an error, or a question from PAM (a prompt for the
//! password, or information to show).

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;

use serde::{Deserialize, Serialize};

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum Request<'a> {
    CreateSession { username: &'a str },
    PostAuthMessageResponse { response: Option<&'a str> },
    StartSession { cmd: Vec<String>, env: Vec<String> },
    CancelSession,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum Response {
    Success,
    Error { error_type: ErrorType, description: String },
    AuthMessage { auth_message_type: AuthMessageType },
}

#[derive(Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
enum ErrorType {
    AuthError,
    Error,
}

#[derive(Deserialize)]
#[serde(rename_all = "snake_case")]
enum AuthMessageType {
    Visible,
    Secret,
    Info,
    Error,
}

#[derive(Debug)]
pub enum LoginError {
    /// The user name or password did not match.
    WrongPassword,
    /// PAM asked for more than the password (an expired password that must
    /// be changed, a second factor): this screen cannot answer that yet.
    NeedsMore,
    /// greetd could not be reached, or refused for another reason.
    Failed(String),
}

/// Checks `username`'s `password` with greetd and, when it matches, has
/// greetd start `session` for them once this greeter exits.
pub fn log_in(username: &str, password: &str, session: &[&str]) -> Result<(), LoginError> {
    let mut greetd = Connection::open()?;
    let mut reply = greetd.send(&Request::CreateSession { username })?;
    let mut password_sent = false;

    // PAM's questions, answered until it says yes or no
    loop {
        match reply {
            Response::Success => break,
            Response::Error { error_type, description } => {
                greetd.cancel();
                if error_type == ErrorType::AuthError {
                    return Err(LoginError::WrongPassword);
                }
                return Err(LoginError::Failed(description));
            }
            Response::AuthMessage { auth_message_type, .. } => {
                let asks_for_input = matches!(
                    auth_message_type,
                    AuthMessageType::Secret | AuthMessageType::Visible
                );
                // Info and error messages only need acknowledging.
                if !asks_for_input {
                    reply = greetd.send(&Request::PostAuthMessageResponse { response: None })?;
                    continue;
                }
                if password_sent {
                    greetd.cancel();
                    return Err(LoginError::NeedsMore);
                }
                password_sent = true;
                let response = Some(password);
                reply = greetd.send(&Request::PostAuthMessageResponse { response })?;
            }
        }
    }

    let cmd = session.iter().map(|part| part.to_string()).collect();
    match greetd.send(&Request::StartSession { cmd, env: Vec::new() })? {
        Response::Success => Ok(()),
        Response::Error { description, .. } => {
            greetd.cancel();
            Err(LoginError::Failed(description))
        }
        Response::AuthMessage { .. } => {
            greetd.cancel();
            Err(LoginError::NeedsMore)
        }
    }
}

struct Connection {
    socket: UnixStream,
}

impl Connection {
    fn open() -> Result<Connection, LoginError> {
        let path = std::env::var("GREETD_SOCK")
            .map_err(|_| LoginError::Failed("not started by greetd (no GREETD_SOCK)".into()))?;
        let socket = UnixStream::connect(&path)
            .map_err(|error| LoginError::Failed(format!("cannot reach greetd: {error}")))?;
        Ok(Connection { socket })
    }

    fn send(&mut self, request: &Request) -> Result<Response, LoginError> {
        let lost = |error: std::io::Error| LoginError::Failed(format!("lost greetd: {error}"));

        let body = serde_json::to_vec(request).expect("requests always serialize");
        let length = (body.len() as u32).to_ne_bytes();
        self.socket.write_all(&length).map_err(lost)?;
        self.socket.write_all(&body).map_err(lost)?;

        let mut length = [0u8; 4];
        self.socket.read_exact(&mut length).map_err(lost)?;
        let mut body = vec![0u8; u32::from_ne_bytes(length) as usize];
        self.socket.read_exact(&mut body).map_err(lost)?;
        serde_json::from_slice(&body)
            .map_err(|error| LoginError::Failed(format!("unexpected answer from greetd: {error}")))
    }

    /// Ends a half-done login, so the next attempt starts clean.  Its own
    /// failure changes nothing for the person at the screen.
    fn cancel(&mut self) {
        let _ = self.send(&Request::CancelSession);
    }
}
