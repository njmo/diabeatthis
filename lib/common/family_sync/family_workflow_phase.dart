/// A future reservation is not an activity monitor lock.
bool familyWorkflowPhaseBlocks(String kind, String phase) =>
    phase != 'idle' && !(kind == 'activity' && phase == 'planned');
