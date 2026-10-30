# Persistent dhikr synchronization

The iPhone and watch share identical DhikrLedger sources. Normalized Arabic titles identify dhikr across devices. Per-device increment components merge by maximum, preserving concurrent increments and making repeated delivery idempotent. Deletion tombstones prevent resurrection from older snapshots. Reset generations supersede increments in older generations. The saved empty list remains empty. Both devices must run this updated protocol; legacy snapshots without ledgerV2 are ignored.

Manual deletion requires confirmation. Tap, swipe, Digital Crown and Double Tap counting remain available. Voice recognition, microphone permissions and remote voice controls have been removed.

Run `sh Tests/LedgerRegression/run.sh` for regression coverage of persistence, Arabic normalization, duplicate migration, concurrent counts, replay, reset, deletion/re-add and 500 interleaved increments. WatchConnectivity delivery remains subject to OS scheduling; physical-device reconnection testing is still needed.
