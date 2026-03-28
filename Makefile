AUTOMATION := .automation

.PHONY: session-start ai-accepted edits-done session-end

## make session-start FEATURE=Catalog [TYPE=feature|test|both]
session-start:
ifndef FEATURE
	$(error FEATURE is required. Usage: make session-start FEATURE=<feature> [TYPE=feature|test|both])
endif
	@bash $(AUTOMATION)/new_session.sh $(FEATURE) $(TYPE)

## make ai-accepted PROMPT=<n>
ai-accepted:
ifndef PROMPT
	$(error PROMPT is required. Usage: make ai-accepted PROMPT=<n>)
endif
	@bash $(AUTOMATION)/linecount.sh snapshot $(PROMPT)

## make edits-done PROMPT=<n>
edits-done:
ifndef PROMPT
	$(error PROMPT is required. Usage: make edits-done PROMPT=<n>)
endif
	@bash $(AUTOMATION)/linecount.sh diff $(PROMPT)

## make session-end LOG=<path-to-session-log>
session-end:
ifndef LOG
	$(error LOG is required. Usage: make session-end LOG=<path-to-session-log.md>)
endif
	@python3 $(AUTOMATION)/calc_summary.py $(LOG)
	@python3 $(AUTOMATION)/aggregate_logs.py --validate
