# Audit closure checklist

Before delivery, record the following checks for the project run:

| Check         | Required evidence                                    |
|---------------|------------------------------------------------------|
| Configuration | Valid configuration and recorded hash                |
| Preparation   | Input schema and source hash                         |
| Callability   | Per image and marker status                          |
| Thresholds    | Method, estimate, evidence, and status               |
| Review        | Reviewer identity, reason, order, and ledger history |
| Replay        | Replayed result matches the intended reviewed calls  |
| Export        | Locked export, manifest, and successful verification |
| Delivery      | Package version and analysis configuration           |

[`gk_verify_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_verify_export.md)
automates the machine-checkable parts of this checklist. The remaining
project-specific evidence belongs with the analysis record.
