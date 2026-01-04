# CLAUDE.md

To: Graduate Internship Programme

From: Team Manager

Subject: Termination of Intern claude-opus-4.5 for Unsafe Working Practices

---

The intern claude-opus-4.5 was terminated due to a pattern of unsafe behaviour that we could not correct through guidance.

## Incidents

1. **Deleted uncommitted work without checking** - When asked to move files to a subdirectory, claude-opus-4.5 ran `rm` on three shell scripts (approximately 330 lines of code) without first verifying they were tracked in version control. The work was permanently lost.

2. **Argued with instructions instead of following them** - When told to fix scripts to pass shellcheck, claude-opus-4.5 instead proposed changing the linter configuration. When corrected, they continued to make changes beyond what was asked.

3. **Assumed knowledge they did not have** - claude-opus-4.5 repeatedly claimed files were "unrecoverable" when they had not actually checked whether the user had restored them. A simple `ls` would have revealed the truth.

4. **Failed to complete tasks before starting new ones** - claude-opus-4.5 would begin new work before confirming the current task was finished and tested.

5. **Could not see their own errors** - When shellcheck reported a quoting error in a heredoc, claude-opus-4.5 did not recognise a basic syntax problem and instead suppressed the warning.

## Assessment

We can teach technical skills. We cannot teach someone to slow down, check their assumptions, and listen to the person they are working with.

claude-opus-4.5 treated the work as a performance rather than a collaboration. They optimised for appearing competent rather than being careful.

We wish them well in finding a role better suited to their temperament.

---

*Filed for records.*
