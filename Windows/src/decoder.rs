use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    PassThrough,
    Consume,
    Launch(String),
}

pub struct Decoder {
    leader: u32,
    timeout: Duration,
    mappings: HashMap<u32, String>,
    deadline: Option<Instant>,
    leader_down_consumed: bool,
}

impl Decoder {
    pub fn new(leader: u32, timeout_ms: u64, mappings: HashMap<u32, String>) -> Self {
        Self {
            leader,
            timeout: Duration::from_millis(timeout_ms),
            mappings,
            deadline: None,
            leader_down_consumed: false,
        }
    }

    pub fn key_down(&mut self, key: u32, modified: bool, now: Instant) -> Action {
        if modified {
            self.deadline = None;
            if key == self.leader {
                self.leader_down_consumed = false;
            }
            return Action::PassThrough;
        }
        if self.deadline.is_some_and(|deadline| now > deadline) {
            self.deadline = None;
        }
        if self.deadline.is_none() {
            if key == self.leader {
                self.deadline = Some(now + self.timeout);
                self.leader_down_consumed = true;
                Action::Consume
            } else {
                Action::PassThrough
            }
        } else if key == self.leader {
            self.deadline = Some(now + self.timeout);
            self.leader_down_consumed = true;
            Action::Consume
        } else {
            self.deadline = None;
            self.mappings
                .get(&key)
                .cloned()
                .map_or(Action::PassThrough, Action::Launch)
        }
    }

    pub fn key_up(&mut self, key: u32) -> bool {
        if key != self.leader {
            return false;
        }
        let consumed = self.leader_down_consumed;
        self.leader_down_consumed = false;
        consumed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn decoder() -> Decoder {
        Decoder::new(
            0x14,
            600,
            HashMap::from([(u32::from(b'G'), "target".into())]),
        )
    }

    #[test]
    fn leader_then_mapping_launches() {
        let now = Instant::now();
        let mut decoder = decoder();
        assert_eq!(decoder.key_down(0x14, false, now), Action::Consume);
        assert_eq!(
            decoder.key_down(u32::from(b'G'), false, now),
            Action::Launch("target".into())
        );
    }

    #[test]
    fn unknown_and_expired_sequences_pass_through() {
        let now = Instant::now();
        let mut decoder = decoder();
        decoder.key_down(0x14, false, now);
        assert_eq!(
            decoder.key_down(u32::from(b'X'), false, now),
            Action::PassThrough
        );
        decoder.key_down(0x14, false, now);
        assert_eq!(
            decoder.key_down(u32::from(b'G'), false, now + Duration::from_millis(601)),
            Action::PassThrough
        );
    }

    #[test]
    fn modified_input_cancels_sequence() {
        let now = Instant::now();
        let mut decoder = decoder();
        decoder.key_down(0x14, false, now);
        assert_eq!(
            decoder.key_down(u32::from(b'G'), true, now),
            Action::PassThrough
        );
        assert_eq!(
            decoder.key_down(u32::from(b'G'), false, now),
            Action::PassThrough
        );
    }

    #[test]
    fn leader_key_up_matches_key_down_handling() {
        let now = Instant::now();
        let mut decoder = decoder();
        decoder.key_down(0x14, true, now);
        assert!(!decoder.key_up(0x14));
        decoder.key_down(0x14, false, now);
        assert!(decoder.key_up(0x14));
    }
}
