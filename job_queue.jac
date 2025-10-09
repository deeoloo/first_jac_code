node queue {
    has name: str;
}

node job {
    has id: str;
    has payload: str;
    has status: str;
    has attempts: int;
    has max_attempts: int;
    has owner: str;
    has notes: list;
}

walker Worker {
    has name: str;

    can start with entry;
    can work  with job entry;

    def generate_ai_note(
        job_id: str,
        payload: str,
        status: str,
        attempts: int,
        max_attempts: int
    ) -> str {
        if status == "done" {
            return "Job " + job_id + " completed successfully; payload " + payload + ".";
        } else {
            let msg = "Job " + job_id + " failed after " + str(attempts) + "/" + str(max_attempts) + " attempts.";
            if attempts < max_attempts {
                msg = msg + " Next: check recent logs and retry.";
            } else {
                msg = msg + " Next: collect error output and escalate.";
            }
            return msg;
        }
    }
}

walker QueueReporter {
    can report with entry;
}

with entry {
    let q  = root ++> queue("main");

    let j1 = q  ++> job("job-1", "resize-image-001.jpg", "pending", 0, 3, "", []);
    let j2 = j1 ++> job("job-2", "generate-report-Q3.csv", "pending", 0, 3, "", []);
    let j3 = j2 ++> job("job-3", "email-campaign-4821", "pending", 0, 3, "", []);
    let j4 = j3 ++> job("job-4", "backup-database-users", "pending", 0, 3, "", []);

    q spawn Worker("W1");
    q spawn Worker("W2");
    q spawn QueueReporter();
}

impl Worker.start {
    if [-->] {
        visit [-->];
    } else {
        print("[" + self.name + "] Queue empty. Nothing to do.");
        disengage;
    }
}

impl Worker.work {
    if here.status == "done" or here.status == "failed" {
        if [-->] {
            visit [-->];
        } else {
            visit root;
            
            if [-->] { visit [-->]; }
            else { disengage; }
        }
    } else {
        if here.status == "pending" {
            here.status = "running";
            here.owner = self.name;
            print("[" + self.name + "] Claimed " + here.id + " (" + here.payload + "). Attempts="
                  + str(here.attempts) + "/" + str(here.max_attempts));
        }

        if here.status == "running" and here.owner == self.name {
           
            let success = here.attempts > 0;

            if success {
                here.status = "done";
                print("[" + self.name + "]  Completed " + here.id);

                let note = self.generate_ai_note(
                    job_id=here.id,
                    payload=here.payload,
                    status="done",
                    attempts=here.attempts,
                    max_attempts=here.max_attempts
                );
                here.notes.append(note);
                print("[" + self.name + "]  Note: " + note);

            } else {
                here.attempts = here.attempts + 1;
                if here.attempts < here.max_attempts {
                    here.status = "pending";
                    print("[" + self.name + "]  Failed " + here.id + ". Retrying ("
                          + str(here.attempts) + "/" + str(here.max_attempts) + ")");
                } else {
                    here.status = "failed";
                    print("[" + self.name + "]  Gave up on " + here.id + " after "
                          + str(here.attempts) + " attempts");

                    let note2 = self.generate_ai_note(
                        job_id=here.id,
                        payload=here.payload,
                        status="failed",
                        attempts=here.attempts,
                        max_attempts=here.max_attempts
                    );
                    here.notes.append(note2);
                    print("[" + self.name + "]  Note: " + note2);
                }
            }
        }

        if [-->] { visit [-->]; }
        else {
            visit root;
            if [-->] { visit [-->]; }
            else { disengage; }
        }
    }
}

impl QueueReporter.report {
    let pending = 0;
    let running = 0;
    let done = 0;
    let failed = 0;

    if [-->] {
        visit [-->];
    } else {
        print("[Reporter] Queue empty.");
        disengage;
    }

    while ( 1 == 1 ) {
        if here is job{
            if here.status == "pending" { pending = pending + 1; }
            if here.status == "running" { running = running + 1; }
            if here.status == "done"    { done    = done    + 1; }
            if here.status == "failed"  { failed  = failed  + 1; }

            if [-->] { visit [-->]; }
            else { break; }
        } else { break; }
    }

    let out = "Pending: " + str(pending) + ", Running: " + str(running) +
              ", Done: " + str(done) + ", Failed: " + str(failed) +
              "\nTips: keep max_attempts reasonable; prefer idempotent steps to allow safe retries.";
    print("\n=== QUEUE SUMMARY ===\n" + out + "\n");
}
