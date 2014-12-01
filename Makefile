.PHONY: run

compile:
	./rebar get-deps compile

run: compile
	ct_run -dir tests -logdir logs -pa ebin -pa deps/*/ebin
