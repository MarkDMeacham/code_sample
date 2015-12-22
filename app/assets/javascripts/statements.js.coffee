window.statement_vm = (data) ->
	ko.mapping.fromJS(data, {}, this)
	this.lines = ko.observableArray()
	this.mapped_data_points = {}
	self = this

	# Adds up the total from each of the lines
	self.total = ko.computed(->
		total = 0.0
		ko.utils.arrayForEach self.lines(), (line) ->
			amount = line.total()
			total += amount unless is_blank(amount)
		return convert_to_currency(total)
	)

	# Data points listeners and formatting are paused until initialized as some can depend on others.
	self.initialize = () ->
		$.each self.mapped_data_points, (k, data_point) ->
			data_point.initialized(true)

	return #statement_vm

window.line_vm = (data) ->
	ko.mapping.fromJS(data, {}, this)
	this.mapped_data_points = {}
	self = this

	return #line_vm

# Normalize the content (i.e. $50.00, 12/25/2015, etc.)
ko.extenders.formatted_content = (target, object) ->
	result = ko.computed(
		read: () ->
			value = target()
			return value unless object.initialized()
			
			if ko.isObservable(object.data_type)
				value = convert_to_data_type(value, object.data_type())
				switch object.data_type()
					when "date"
						value = if is_blank(value) then '' else moment(value).format('M/D/YYYY')
					when "currency"
					  value = if value == 0 then '' else convert_to_currency(value)
					when "percent"
					  value = if value == 0 then '' else convert_to_percent(value)
			
			return value
		write: (newValue) ->
			return unless object.initialized()
			object.content(newValue) # Write back the actual value to content so it can update if needed
	).extend(notify: 'always')
	result(target())
	return result

# Maintain and update the actual content (i.e. 50.0, 2015-12-25, etc.)
ko.extenders.content = (target, object) ->
	result = ko.computed(
		read: () ->
			value = target()
			return value unless object.initialized()			
			value = convert_to_data_type(value, object.data_type()) if ko.isObservable(object.data_type)
			return value
		write: (newValue) ->
			return unless object.initialized()
			current = target()
			value = newValue

			value = convert_to_data_type(value, object.data_type()) if ko.isObservable(object.data_type)

			# Only update if the value has actually changed, otherwise just update the observables
			if value != current
				target(value)
				update_data_points(object.uid(), value)
			else if newValue != current
				target.notifySubscribers(value)
			return
	).extend(notify: 'always')
	result(target())
	return result

# Helper for converting a value based on data type
window.convert_to_data_type = (value, data_type) ->
	switch data_type
		when "boolean"
			return value == "true" || value == true
		when "date"
			return if is_blank(value) then '' else moment(value).format('YYYY-MM-DD')
		when "currency", "percent"
			return Number(String(value).replace(/[^\d\.\-]/g, ''))
	return value

window.data_point_vm = (data) ->
	ko.mapping.fromJS(data, {}, this)
	self = this
	self.initialized = ko.observable(false)

	# Extend the observables with the above extenders.
	self.formatted_content = self.content.extend({formatted_content: self})
	self.content = self.content.extend({content: self})

	self.placeholder = () ->
		return titleize(self.tag())

	# Calculate based on listener function. Doesn't run unless initialized and actually has a listener.
	self.listening_value = ko.computed(->
		return unless self.initialized() && ko.isObservable(self.listener)
		switch self.listener()
			when "commission_amount"
				line = self.line
				amount = if line.amount() && line.percent() then line.amount() * line.percent() / 100.0 else ''
				self.content amount
			when "proration_amount"
				line = self.line
				amount = ''
				if line.start_date() && line.proration_date() && line.end_date() && line.amount()
					prorated_diff = date_difference(line.start_date(), line.proration_date())
					total_diff = date_difference(line.start_date(), line.end_date())
					amount = line.amount() / total_diff * prorated_diff
				self.content amount
	)

	return #data_point_vm

# Transactional update of data points. Queues updates until timer has expired.
window.updates = {}
window.update_data_points = (uid, value) ->
	updates[uid] = value
	clearTimeout(window.update_timer)
	window.update_timer = setTimeout( ->
		params = {data_points: window.updates}
		window.updates = {}
		$.ajax(
			url: "/statements/#{statement.id()}/update_data_points"
			type: "put"
			data: params
		)
	, 500)

window.is_blank = (value) ->
	return value == '' || value == null || value == undefined

window.convert_to_currency = (value) ->
	return '' if is_blank(value)
	value = String(value).replace(/[^\d\.\-]/g, '')
	value = "$#{parseFloat(value).toFixed(2).replace(/(\d)(?=(\d{3})+\.)/g, '$1,')}"

window.convert_to_percent = (value) ->
	return '' if is_blank(value)
	value = String(value).replace(/[^\d\.\-]/g, '')
	value = "#{parseFloat(value).toFixed(4).replace(/(\d)(?=(\d{3})+\.)/g, '$1,')}%"

window.date_difference = (start, end) ->
	return 0 unless start && end
	day = 1000*60*60*24
	return Math.floor((new Date(end) - new Date(start)) / day)

# Normalize a variable name (i.e. user_name to User Name)
window.titleize = (value) ->
	list = []
	$.each value.split("_"), (index, word) ->
		list.push "#{word[0].toUpperCase()}#{word.slice(1)}"
	return list.join(" ")

# Attach a datepicker on focus if the element does not have one
$(document).on "focus", ".datepicker:not(.hasDatepicker)", () ->
	$(this).datepicker(
		changeMonth: true
		changeYear: true
	)