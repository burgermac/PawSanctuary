import Foundation

// ============================================================
// MARK: - KIBBLE DRIVE — persisted state
// ============================================================

/// One Kibble Drive's in-flight state (`specs/Spec_KibbleDrive_Draft.md` §5,
/// schema v42). The Drive is a paid, activity-gated ladder: the purchase
/// delivers nothing directly, it makes rungs *claimable*, and the player
/// releases them by earning Drive Points through ordinary play across the
/// event's window.
///
/// **`points` is event-scoped on purpose, and this is the single most likely
/// error in the whole feature** (§1's "weekly-reset trap"). The Drive is fed by
/// the same activity chokepoint as Care Points, but `carePointsThisWeek`
/// (`GameState`) zeroes at `checkWeeklyGoalReset`'s boundary. A Drive window
/// straddling that boundary would zero its own ladder mid-event and destroy a
/// purchase. So this accumulator is reset on the *Drive's* lifecycle and must
/// never be derived from, or kept in sync with, `carePointsThisWeek`.
///
/// `eventID` is what scopes it: state belonging to a finished Drive is not
/// carried into the next one. It also backs the time-of-check/time-of-use guard
/// §5 inherits from `Spec_Phase6b_Pass.md` §3.3 — a purchase that resolves after
/// the window closes must not credit the Drive that follows it.
///
/// Nothing reads or writes this yet. It lands ahead of the logic (§6 step 1) so
/// the schema change is its own separately verifiable commit rather than riding
/// in with behaviour.
struct KibbleDriveState: Codable, Equatable {
    /// The `EventDefinition` this state belongs to. Never blank — a Drive with
    /// no event is not a Drive, which is why `GameState.kibbleDrive` is
    /// Optional rather than this field being defaulted.
    var eventID: String
    /// Drive Points banked this event. Credited alongside `carePointsThisWeek`
    /// rather than taken from it — the two are non-rivalrous, which is the
    /// whole architectural point of §1.
    var points: Int = 0
    /// Rung indices already claimed, so a claimed rung stays claimed across a
    /// relaunch. Indices into the event's ladder, not thresholds: thresholds
    /// live in registry content and a later retune of them must not silently
    /// re-open rungs a player already took.
    var claimedRungs: [Int] = []
    /// Whether this Drive's one-time IAP has been purchased. Points accrue
    /// either way (§2) — an unpurchased player watches the ladder fill with
    /// every rung locked, and that visible-but-locked accumulation *is* the
    /// offer.
    var purchased: Bool = false
}
