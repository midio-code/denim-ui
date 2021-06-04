test_dsl:
	nim c -r ./tests/t_gui_dsl.nim

test: test_dsl
	nim c -r ./tests/t_rect.nim
	nim c -r ./tests/t_event_to_observable.nim
	nim c -r ./tests/t_layout_tests.nim
	nim c -r ./tests/t_animations.nim
	nim c -r ./tests/t_element_observables.nim
	nim c -r ./tests/t_element_events.nim
	nim c -r ./tests/t_guid.nim
.PHONY: test_dsl test
