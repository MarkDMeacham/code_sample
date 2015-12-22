class Statement < ActiveRecord::Base
	before_create :initialize_data
	attr_accessor :xml_data

	# Create the initial XML using the Nokogiri Builder
	def initialize_data
		# Settting up the lines with their data points. 
		lines = [
			{line_type: "proration", data_points: [{tag: "description", content: "Proration"}, {tag: "start_date", data_type: "date"}, {tag: "proration_date", data_type: "date"}, {tag: "end_date", data_type: "date"},{tag: "amount", data_type: "currency"},{tag: "total", listener: "proration_amount", data_type: "currency"}]},
			{line_type: "commission", data_points: [{tag: "description", content: "Commission"}, {tag: "amount", data_type: "currency"}, {tag: "percent", data_type: "percent"}, {tag: "total", data_type: "currency", listener: "commission_amount"}]},
			{line_type: "description", data_points: [{tag: "description", content: "Description"}, {tag: "total", data_type: "currency"}]},
		]

		builder = Nokogiri::XML::Builder.new do |xml|
			xml.root{
				xml.lines{
					lines.each_with_index do |line, index|
						# Set up the line attributes
						line_uid = "line#{index}"
						xml.line(line.except(:data_points).merge(uid: line_uid)){
							line[:data_points].each do |data_point|
								# Create the data point. Everything but the content is treated as an attribute. 
								# uid makes for easier access on view and in model.
								xml.data_point(data_point.except(:content).merge(uid: "#{line_uid}.#{data_point[:tag]}"), data_point[:content])
							end
						}
					end
				}
			}
		end
		self.data = builder.to_xml
	end

	def to_vm ; return self.to_json(except: [:data]) ; end
	def save_data ; self.update_attributes(data: self.data.to_xml) ; end

	# Put the parsed XML into memory for faster access everywhere and so our parsed XML is not overwritten by another function.
	def data
		self.xml_data = Nokogiri::XML(super) unless self.xml_data
		return self.xml_data
	end

	# Collect the lines and their data points for view.
	def lines
		list = []
		self.data.css("line").each do |line|
			info = {}
			line.attributes.each{|k, attribute| info[k.to_sym] = attribute.value}

			info[:data_points] = []
			line.css("data_point").each do |data_point|
				data_point_info = {}
				data_point.attributes.each{|k, attribute| data_point_info[k.to_sym] = attribute.value}
				data_point_info[:content] = data_point.content
				info[:data_points] << data_point_info
			end

			list << info
		end
		return list
	end

	def update_data_points(updates)
		selector = updates.collect{|uid, content| "data_point[uid='#{uid}']"}.join(", ")
		self.data.css(selector).each do |data_point|
			data_point.content = updates[data_point['uid']]
		end
		self.save_data
	end
end
