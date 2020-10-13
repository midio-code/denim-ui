test_dsl:
	nim c --path="../src/" -r ./tests/t_gui_dsl.nim

test: test_dsl
	nim c --path="../src/" -r ./tests/t_observable.nim
	nim c --path="../src/" -r ./tests/t_rect.nim
	nim c --path="../src/" -r ./tests/t_state_machine.nim
	nim c --path="../src/" -r ./tests/t_event_to_observable.nim
	nim c --path="../src/" -r ./tests/t_layout_tests.nim
	nim c --path="../src/" -r ./tests/t_animations.nim
	nim c --path="../src/" -r ./tests/t_element_observables.nim
	nim c --path="../src/" -r ./tests/t_element_events.nim

.PHONY: test_dsl test
