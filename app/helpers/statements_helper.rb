module StatementsHelper
	# Helpers for creating inputs on form
	def input
		return text_field_tag(:content, nil, data: {bind: "value: formatted_content, attr: {id: uid(), placeholder: placeholder()}"})
	end

	def datepicker
		return text_field_tag(:content, nil, data: {bind: "value: formatted_content, attr: {id: uid(), placeholder: placeholder()}"}, class: "datepicker")
	end
end
