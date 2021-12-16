data:extend({
	{
		type = "int-setting",
		name = "TfC_max_speed_bonus",
		setting_type = "runtime-global",
		default_value = 6,
		minimum_value = 1,
		maximum_value = 100
	}, {
		type = "int-setting",
		name = "TfC_max_compensated_ticks",
		setting_type = "runtime-global",
		maximum_value = 60 * 60 * 60,
		default_value = 60 * 60 * 2,
		minimum_value = 1
	}, {
		type = "int-setting",
		name = "TfC_minimum_speed_bonus",
		setting_type = "runtime-global",
		default_value = 0,
		minimum_value = -10,
		maximum_value = 10
	}
})
