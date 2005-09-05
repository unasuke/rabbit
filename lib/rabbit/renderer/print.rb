require "gnomeprint2"

require "rabbit/renderer/base"

module Rabbit
  module Renderer

    class Print

      include Base
      
      attr_writer :foreground, :background, :background_image
      attr_accessor :filename
      
      def initialize(canvas)
        super
        @filename = nil
        @background_image = nil
        init_job
        init_printers
        init_paper
        init_color
      end

      def page_width
        @page_width - margin_page_left - margin_page_right
      end
      alias width page_width
      
      def page_height
        @page_height - margin_page_top - margin_page_bottom
      end
      alias height page_height
      
      def paper_width=(value)
        super
        init_paper
      end
      
      def paper_height=(value)
        super
        init_paper
      end
      
      def pre_print(slide_size)
        update_filename
      end
      
      def post_print
        @job.close
        @job.print
      end

      def post_apply_theme
      end

      def post_move(index)
      end
      
      def post_fullscreen
      end
      
      def post_unfullscreen
      end
      
      def post_iconify
      end
      
      def post_toggle_index_mode
      end
      
      def post_parse_rd
        update_title
      end

      
      def index_mode_on
      end
      
      def index_mode_off
      end


      def draw_slide(slide, simulation)
        if simulation
          yield
        else
          # @context.begin_page(slide.title) do
          @context.begin_page do
            draw_background
            yield
          end
        end
      end
      
      def draw_line(x1, y1, x2, y2, color=nil)
        x1, y1 = from_screen(x1, y1)
        x2, y2 = from_screen(x2, y2)
        color = make_color(color)
        @context.save do
          set_color(color)
          @context.line_stroked(x1, y1, x2, y2)
        end
      end
      
      def draw_rectangle(filled, x1, y1, x2, y2, color=nil)
        x1, y1 = from_screen(x1, y1)
        y1 -= y2
        color = make_color(color)
        @context.save do
          set_color(color)
          if filled
            @context.rect_filled(x1, y1, x2, y2)
          else
            @context.rect_stroked(x1, y1, x2, y2)
          end
        end
      end
      
      # can't draw ellipse
      def draw_arc(filled, x, y, w, h, a1, a2, color=nil)
        x, y = from_screen(x, y)
        a1, a2 = convert_angle(a1, a2)
        color = make_color(color)
        @context.save do
          set_color(color)
          radius = w / 2
          @context.arc_to(x + radius, y - radius, radius, a1, a2, false)
          if filled
            @context.fill
          else
            @context.stroke
          end
        end
      end
      
      def draw_circle(filled, x, y, w, h, color=nil)
        draw_arc(filled, x, y, w, h, 0, 359, color)
      end

      def draw_polygon(filled, points, color=nil)
        return if points.empty?
        color = make_color(color)
        @context.save do
          set_color(color)
          @context.move_to(*from_screen(*points.first))
          points[1..-1].each do |x, y|
            @context.line_to(*from_screen(x, y))
          end
          @context.line_to(*from_screen(*points.first))
          if filled
            @context.fill
          else
            @context.stroke
          end
        end
      end
      
      def draw_layout(layout, x, y, color=nil)
        x, y = from_screen(x, y)
        color = make_color(color)
        @context.save do
          set_color(color)
          @context.move_to(x, y)
          @context.layout(layout)
        end
      end
      
      def draw_pixbuf(pixbuf, x, y, params={})
        x, y = from_screen(x, y)
        color = make_color(params['color'])
        width = params['width'] || pixbuf.width
        height = params['height'] || pixbuf.height
        args = [pixbuf.pixels, width, height, pixbuf.rowstride]
        @context.save do
          @context.translate(x, y - height)
          @context.scale(width, height)
          if pixbuf.has_alpha?
            @context.rgba_image(*args)
          else
            @context.rgb_image(*args)
          end
        end
      end
      

      def make_color(color, default_is_foreground=true)
        if color.nil?
          if default_is_foreground
            @foreground
          else
            @background
          end
        else
          Color.new_from_gdk_color(Gdk::Color.parse(color))
        end
      end

      def make_layout(text)
        attrs, text = Pango.parse_markup(text)
        layout = @context.create_layout
        layout.text = text
        layout.set_attributes(attrs)
        layout.context_changed
        w, h = layout.size.collect {|x| x / Pango::SCALE}
        [layout, w, h]
      end
      
      def create_pango_context
        Gnome::PrintPango.create_context(Gnome::PrintPango.default_font_map)
      end

      def printable?
        true
      end

      def clear_theme
        init_job
        init_color
        @background_image = nil
      end
      
      private
      def init_job
        @job = Gnome::PrintJob.new
        @context = @job.context
        @config = @job.config
      end

      def init_printers
        @printers = Gnome::GPARoot.printers
      end
      
      def init_paper
        setup_paper
        @page_width = get_length_by_point(Gnome::PrintConfig::KEY_PAPER_WIDTH)
        @page_height = get_length_by_point(Gnome::PrintConfig::KEY_PAPER_HEIGHT)
      end

      def setup_paper
        pt = unit("Pt")
        if size_set?
          @config[Gnome::PrintConfig::KEY_PAPER_SIZE] = "Custom"
          @config.set(Gnome::PrintConfig::KEY_PAPER_WIDTH, @paper_width, pt)
          @config.set(Gnome::PrintConfig::KEY_PAPER_HEIGHT, @paper_height, pt)
        else
          paper = Gnome::PrintPaper.get("A4")
          @config[Gnome::PrintConfig::KEY_PAPER_SIZE] = "Custom"
          @config.set(Gnome::PrintConfig::KEY_PAPER_WIDTH, paper.height, pt)
          @config.set(Gnome::PrintConfig::KEY_PAPER_HEIGHT, paper.width, pt)
        end
      end

      def size_set?
        @paper_width and @paper_height
      end

      def get_length_by_point(key, *args)
        pt = unit("Pt")
        length, _unit = @config[key, :length]
        _unit.convert_distance(length, pt, *args)
      end
      
      def unit(abbr_name)
        Gnome::PrintUnit.get_by_abbreviation(abbr_name)
      end
      
      def init_color
        @white = make_color("white")
        @black = make_color("black")
        @foreground = make_color("black")
        @background = make_color("white")
      end
      

      def from_screen(x, y)
        [x + margin_page_left, height - y + margin_page_bottom]
      end

      def convert_angle(a1, a2)
        a2 += a1
        a2 -= 360 if a2 > 360
        [a1, a2]
      end
      
      def set_color(color)
        @context.set_rgb_color(color.red, color.green, color.blue)
      end


      def draw_background
        draw_rectangle(true, 0, 0, width, height, @background.to_s)
        if @background_image
          params = {
            "width" => [@background_image.width, width].min,
            "height" => [@background_image.height, height].min,
          }
          draw_pixbuf(@background_image, 0, 0, params)
        end
      end
      

      def update_filename
        filename = @filename || "#{GLib.filename_from_utf8(@canvas.title)}.ps"
        update_printer(filename)
        @job.print_to_file(filename)
        init_paper
      end
      
      def update_title
        @config[Gnome::PrintConfig::KEY_DOCUMENT_NAME] = @canvas.title
      end

      def update_printer(filename)
        printer = find_printer(filename)
        if printer
          @config["Printer"] = printer.id
        else
          @canvas.logger.warn(_("can't find printer for %s") % filename)
        end
      end
      
      def find_printer(filename)
        if filename[0] == ?|
          @printers.find do |printer|
            /Postscript/i =~ printer.value
          end
        else
          case File.extname(filename)
          when /\.ps/i
            @printers.find do |printer|
              /Postscript/i =~ printer.value
            end
          when /\.pdf/i
            @printers.find do |printer|
              /PDF/i =~ printer.value
            end
          else
            nil
          end
        end
      end
    end
    
  end
end

