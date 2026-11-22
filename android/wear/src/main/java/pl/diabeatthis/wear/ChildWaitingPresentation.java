package pl.diabeatthis.wear;

import org.json.JSONObject;

record ChildWaitingPresentation(int heading, String caregiver, long deadline, boolean claimed,
                                boolean deciding) {
    static ChildWaitingPresentation from(JSONObject request, long now) {
        long deadline = request.optLong("deadlineMs");
        if ("accepting".equals(request.optString("status"))) {
            return new ChildWaitingPresentation(R.string.accepting, "", deadline, false, false);
        }
        boolean claimed = request.optLong("claimUntilMs") > now;
        boolean deciding = claimed && "decision".equals(request.optString("stage"));
        return new ChildWaitingPresentation(!claimed ? R.string.child_parent_waiting
            : deciding ? R.string.child_parent_deciding : R.string.child_parent_reviewing,
            claimed ? request.optString("caregiverName") : "", deadline, claimed, deciding);
    }
}
