.PHONY: run

run:
	ct_run -dir tests -logdir logs -pa ebin -pa deps/*/ebin
