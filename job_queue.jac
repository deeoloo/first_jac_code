"""A Simple Job Queue with Retries (Jac)"""

import random;

# A queue "index" node that points to the first job in a singly linked list.
node queue { has name: str; }

# Each job is a node in the list; fields track state and retry attempts.
node job {
    has id: str;
    has payload: str;
    has status: str = "pending";      # pending | running | done | failed
    has attempts: int = 0;
    has max_attempts: int = 3;
    has owner: str = "";              # which worker last claimed it (informational)
}

# A worker walker that traverses the queue and processes jobs.
walker Worker {
    has name: str;

    can start with queue entry;   # enter via the queue head
    can work  with job entry;     # process an individual job node
}

# --- Demo wiring: make one queue, chain some jobs, spawn 2 workers ---

with entry:__main__ {
    let q = root ++> queue("main");
    let j1 = q ++> job("job-1", "resize-image-001.jpg");
    let j2 = j1 ++> job("job-2", "generate-report-Q3.csv");
    let j3 = j2 ++> job("job-3", "email-campaign-4821");
    let j4 = j3 ++> job("job-4", "backup-database-users");

    # Spawn workers ON the queue node
    q spawn Worker("W1");
    q spawn Worker("W2");

}

# --- Worker behavior ---

impl Worker.start {
    # At the queue node: if it has a next edge (head job), visit it; otherwise we're done.
    if [-->] {
        visit [-->];
    } else {
        print(f"[{self.name}] Queue empty. Nothing to do.");
        disengage;
    }
}

impl Worker.work {
    # Quick exit if this job has already finished.
    if here.status == "done" or here.status == "failed" {
        # Move to next job in the chain if present; else back to queue to check again.
        if [-->] {
            visit [-->];
        } else {
            # No next job; jump back to queue head to see if anything new appeared.
            visit [root --> (`?queue)];
        }
    } else {
        # Attempt to "claim" the job if it's pending. If another worker already set it
        # to running, we'll skip it on the next tick.
        if here.status == "pending" {
            here.status = "running";
            here.owner = self.name;
            print(f"[{self.name}] Claimed {here.id} ({here.payload}). Attempts={here.attempts}/{here.max_attempts}");
        }

        if here.status == "running" and here.owner == self.name {
            # Simulate doing the work. Tune success probability as desired.
            let success = random.random() < 0.7;

            if success {
                here.status = "done";
                print(f"[{self.name}] ✅ Completed {here.id}");
            } else {
                here.attempts = here.attempts + 1;
                if here.attempts < here.max_attempts {
                    here.status = "pending";   # put it back in the queue
                    print(f"[{self.name}] ❌ Failed {here.id}. Retrying ({here.attempts}/{here.max_attempts})");
                } else {
                    here.status = "failed";
                    print(f"[{self.name}] 🛑 Gave up on {here.id} after {here.attempts} attempts");
                }
            }
        }

        # Move along the chain; if no next job, bounce to the queue head to scan again.
        if [-->] {
            visit [-->];
        } else {
            visit [root --> (`?queue)];
        }
    }
}
