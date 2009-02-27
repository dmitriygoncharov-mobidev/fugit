include Wx

module Fugit
	class PushDialog < Dialog
		def initialize(parent)
			super(parent, ID_ANY, "Push branches", :size => Size.new(400, 500))

			@branch_list = CheckListBox.new(self, ID_ANY)
			@log = TextCtrl.new(self, ID_ANY, :size => Size.new(20, 150), :style => TE_MULTILINE|TE_DONTWRAP|TE_READONLY)
			@progress = Gauge.new(self, ID_ANY, 100, :size => Size.new(20, 20))

			@remote = ComboBox.new(self, ID_ANY)

			check_panel = Panel.new(self, ID_ANY)
			@tag_check = CheckBox.new(check_panel, ID_ANY)
			@force_check = CheckBox.new(check_panel, ID_ANY)

			flex = FlexGridSizer.new(1,2,4,4)
			flex.add(@tag_check, 0, EXPAND)
			flex.add(StaticText.new(check_panel, ID_ANY, "Include tags"), 0, EXPAND)
			flex.add(@force_check, 0, EXPAND)
			flex.add(StaticText.new(check_panel, ID_ANY, "Force update"), 0, EXPAND)

			check_panel.set_sizer(flex)

			butt_sizer = create_button_sizer(OK|CANCEL)
			butt_sizer.get_children.map {|s| s.get_window}.compact.each {|b| b.set_label(b.get_label == "OK" ? "Push" : "Close")}
			evt_button(get_affirmative_id, :on_ok)

			box = BoxSizer.new(VERTICAL)
			box2 = BoxSizer.new(HORIZONTAL)

			box2.add(@branch_list, 1, EXPAND|LEFT|RIGHT|BOTTOM, 4)
			box2.add(check_panel, 1)

			box.add(StaticText.new(self, ID_ANY, "Select branches:"), 0, EXPAND|ALL, 4)
			box.add(box2, 1, EXPAND)
			box.add(StaticText.new(self, ID_ANY, "Push to:"), 0, EXPAND|ALL, 4)
			box.add(@remote, 0, EXPAND|LEFT|RIGHT|BOTTOM, 4)
			box.add(StaticText.new(self, ID_ANY, "Output:"), 0, EXPAND|ALL, 4)
			box.add(@log, 0, EXPAND|LEFT|RIGHT, 4)
			box.add(@progress, 0, EXPAND|ALL, 4)
			box.add(butt_sizer, 0, EXPAND|BOTTOM, 4)

			self.set_sizer(box)
		end

		def show
			branches = `git branch`
			remotes = `git remote`
			@remote.clear
			remotes = remotes.split("\n")
			remotes.each {|r| @remote.append(r)}
			@remote.set_value(remotes.include?("origin") ? "origin" : remotes[0])
			current = branches.match(/\* (.+)/).to_a.last
			branches = branches.split("\n").map {|b| b.split(" ").last}
			@branch_list.set(branches)
			@branch_list.check(@branch_list.find_string(current)) if current

			@progress.set_value(0)
			@log.clear

			super
		end

		def on_ok
			@progress.set_value(0)
			failed = false
			last_line_type = nil

			branches = @branch_list.get_checked_items.map {|i| @branch_list.get_string(i)}
			tags = @tag_check.is_checked ? "--tags " : ""
			force = @force_check.is_checked ? "--force " : ""
			remote = @remote.get_value
			command = "git push #{tags}#{force}#{remote} #{branches.join(" ")}"
			@log.append_text("#{@log.get_last_position == 0 ? "" : "\n\n"}> #{command}")

			IO.popen("#{command} 2>&1") do |io|
				while line = io.get_line
					last_line_type = case line
						when "Everything up-to-date"
							@progress.set_value(100)
							update_log(last_line_type, nil, line)
						when /Counting objects: \d+, done./
							@progress.set_value(10)
							update_log(last_line_type, :counting, line)
						when /Counting objects: \d+/
							update_log(last_line_type, :counting, line)
						when /Compressing objects:\s+\d+% \((\d+)\/(\d+)\)/
							@progress.set_value(10 + (45*$1.to_f/$2.to_f).to_i)
							update_log(last_line_type, :compressing, line)
						when /Writing objects:\s+\d+% \((\d+)\/(\d+)\)/
							@progress.set_value(55 + (45*$1.to_f/$2.to_f).to_i)
							update_log(last_line_type, :writing, line)
						when /\[rejected\]/
							failed = true
							@progress.set_value(100)
							update_log(last_line_type, nil, line)
						else
							update_log(last_line_type, nil, line)
						end
				end
			end

			#~ end_modal(ID_OK) if success
		end

		def update_log(last, current, line)
			if last == current && !last.nil?
				@log.replace(@log.xy_to_position(0, @log.get_number_of_lines - 1), @log.get_last_position, line)
			else
				@log.append_text("\n" + line)
			end
			current
		end

	end
end