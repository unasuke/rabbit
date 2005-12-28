require "erb"
require "stringio"

require "gtk2"

require "rabbit/gettext"
require "rabbit/utils"
require "rabbit/theme/searcher"
require "rabbit/image"
require "rabbit/action"

module Rabbit
  class Menu
    include GetText
    include ERB::Util

    @@icon = nil

    def initialize(actions)
      @merge = Gtk::UIManager.new
      @merge.insert_action_group(actions, 0)
      @jump_actions = nil
      @jump_merge_id = nil
      @theme_actions = nil
      @theme_merge_id = nil
      update_ui
    end

    def accel_group
      @merge.accel_group
    end

    def update_menu(canvas)
      update_jump_menu(canvas)
      update_theme_menu(canvas)
      canvas.action("PreviousSlide").sensitive = canvas.have_previous_slide?
      canvas.action("NextSlide").sensitive = canvas.have_next_slide?
      canvas.action("FirstSlide").sensitive = !canvas.first_slide?
      canvas.action("LastSlide").sensitive = !canvas.last_slide?
      canvas.action("ClearGraffiti").sensitive = canvas.graffiti_mode?
      @merge.ensure_update
      show_tearoff
    end

    def popup(button, time)
      @menu.popup(nil, nil, button, time)
    end
    
    private
    def update_jump_menu(canvas)
      @merge.remove_ui(@jump_merge_id) if @jump_merge_id
      @merge.remove_action_group(@jump_actions) if @jump_actions

      @jump_merge_id = @merge.new_merge_id
      @jump_actions = Gtk::ActionGroup.new("JumpActions")
      @merge.insert_action_group(@jump_actions, 0)
      jump_path = "/popup/Jump"
      canvas.slides.each_with_index do |slide, i|
        name = "Jump#{i}"
        label = "#{i}: #{Utils.unescape_title(slide.title)}"
        tooltip = _("Jump to the %dth slide") % i
        action = Gtk::Action.new(name, label, tooltip, nil)
        action.signal_connect("activate") do
          canvas.activate("Jump") {i}
        end
        @jump_actions.add_action(action)
        @merge.add_ui(@jump_merge_id, jump_path, name, name,
                      Gtk::UIManager::AUTO, false)
      end
    end
    
    def update_ui
      @merge_ui = @merge.add_ui(ui_xml)
      @menu = @merge.get_widget("/popup")
      tearoff = Gtk::TearoffMenuItem.new
      tearoff.show
      @menu.prepend(tearoff)
    end

    def update_theme_menu(canvas)
      @merge.remove_ui(@theme_merge_id) if @theme_merge_id
      @merge.remove_action_group(@theme_actions) if @theme_actions
      
      @theme_merge_id = @merge.new_merge_id
      @theme_actions = Gtk::ActionGroup.new("ThemeActions")
      @merge.insert_action_group(@theme_actions, 0)

      themes = Theme::Searcher.collect_theme
      
      categories = themes.collect do |entry|
        entry.category
      end.uniq.sort_by {|cat| _(cat)}

      change = "/popup/ChangeTheme"
      merge = "/popup/MergeTheme"

      categories.each do |category|
        theme_menu_add_category("Change", change, category)
        theme_menu_add_category("Merge", merge, category)
      end

      themes.each do |entry|
        theme_menu_add_theme("Change", change, entry, canvas)
        theme_menu_add_theme("Merge", merge, entry, canvas)
      end
    end

    def theme_menu_add_category(prefix, path, category)
      name = "#{prefix}ThemeCategory#{category}"
      label = _(category)
      action = Gtk::Action.new(name, label, nil, nil)
      @theme_actions.add_action(action)
      @merge.add_ui(@theme_merge_id, path, category, name,
                    Gtk::UIManager::MENU, false)
    end

    def theme_menu_add_theme(prefix, path, entry, canvas)
      path = "#{path}/#{entry.category}"
      name = "#{prefix}ThemeEntry#{entry.name}"
      label = _(entry.name)
      action = Gtk::Action.new(name, label, nil, nil)
      action.signal_connect("activate") do
        canvas.activate("#{prefix}Theme") {entry}
      end
      @theme_actions.add_action(action)
      @merge.add_ui(@theme_merge_id, path, entry.name, name,
                    Gtk::UIManager::AUTO, false)
    end

    def show_tearoff(sub_menus=@menu.children)
      sub_menus.each do |child|
        if child.respond_to?(:submenu) and child.submenu
          tearoff, *child_sub_menus = child.submenu.children
          tearoff.show
          show_tearoff(child_sub_menus)
        end
      end
    end

    def ui_xml
      format_xml(ui_axml)
    end

    def format_xml(axml)
      output = StringIO.new
      @indent = "  "
      _format_xml(axml, output, 0)
      output.rewind
      output.read
    end

    def _format_xml(axml, output, indent)
      case axml
      when Array
        tag, *others = axml
        output.print("#{@indent * indent}<#{tag}")
        if others.first.is_a?(Hash)
          attrs, *others = others
          attrs.each do |key, value|
            output.print(" #{h(key)}=\"#{h(value)}\"") if value
          end
        end
        if others.empty?
          output.print("/>\n")
        else
          output.print(">\n")
          others.each do |other|
            _format_xml(other, output, indent + 1)
          end
          output.print("#{@indent * indent}</#{tag}>\n")
        end
      when String
        output.print(h(axml))
      else
        raise "!?!?!?: #{axml.inspect}"
      end
    end

    def ui_axml
      [:ui,
        [:popup,
          *items.collect do |key, name|
            params = {:name => name, :action => name}
            case key
            when :separator
              [:separator]
            when :item
              [:menuitem, params]
            when :menu
              [:menu, params]
            end
          end
        ]
      ]
    end
    
    def items
      [
        [:item, "ToggleIndexMode"],
        [:separator],
        [:item, "ToggleGraffitiMode"],
        [:item, "ClearGraffiti"],
        [:separator],
        [:item, "ToggleFullScreen"],
        [:separator],
        [:item, "RadioBlankWhiteOut"],
        [:item, "RadioBlankBlackOut"],
        [:item, "RadioBlankShow"],
        [:separator],
        [:item, "ToggleCommentFrame"],
        [:item, "ToggleCommentView"],
        [:separator],
        [:menu, "Jump"],
        [:separator],
        [:item, "PreviousSlide"],
        [:item, "NextSlide"],
        [:item, "FirstSlide"],
        [:item, "LastSlide"],
        [:separator],
        [:item, "Iconify"],
        [:separator],
        [:item, "Redraw"],
        [:item, "ReloadTheme"],
        [:menu, "ChangeTheme"],
        [:menu, "MergeTheme"],
        [:separator],
        [:item, "CacheAllSlides"],
        [:separator],
        [:item, "SaveAsImage"],
        [:item, "Print"],
        [:separator],
        [:item, "ResetAdjustment"],
        [:separator],
        [:item, "Quit"],
      ]
    end
  end
end
