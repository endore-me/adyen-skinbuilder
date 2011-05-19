require 'rack'

module Adyen
  module SkinBuilder
    class SkeletonAdapter
      
      def initialize(skins_directory, skin)
        @skins_directory = skins_directory
        @skin = skin
      end
      
      def call(env)
        body = File.read(File.join(File.dirname(__FILE__), '../../adyen/skeleton.html'))
        body = body.gsub(/\$skinCode/, @skin)
        %w(cheader pmheader pmfooter customfields cfooter).each do |inc|
          body = body.gsub(%r{\<!-- ### inc\/#{inc}_\[locale\].txt or inc\/#{inc}.txt \(fallback\) ### --\>}, get_inc(inc))
        end
        body = body.gsub(%r{\<!-- Adyen Main Content --\>}, File.read(File.join(File.dirname(__FILE__), '../../adyen/main_content.html')))
        
        [200, {'Content-Type' => 'text/html'}, [body]]
      end
      
      private
      
      # TODO: add locale support so files like inc/cheader_[locale].txt will be included correctly
      def get_inc(filename)
        if File.exists?(File.join(@skins_directory, @skin, 'inc', "#{filename}.txt"))
          File.read(File.join(@skins_directory, @skin, 'inc', "#{filename}.txt"))
        elsif File.exists?(File.join(@skins_directory, 'base', 'inc', "#{filename}.txt"))
          File.read(File.join(@skins_directory, 'base', 'inc', "#{filename}.txt"))
        else
          "<!-- == #{filename}.txt IS MISSING == -->"
        end
      end
    end
    
    class Server
      
      class << self

        def run(config)
          handler = Rack::Handler.default
          handler.run(self.app(config), :Port => config[:port], :AccessLog => [])
        end
      
        def app(config)
          Rack::Builder.app do
            use Rack::CommonLogger if config[:log]
            use Rack::Head
            
            # TODO: process Adyen default files at "/hpp"
            map("/sf/#{config[:skin]}") do
              run Rack::Cascade.new([
                Rack::File.new(File.join(config[:skins_directory], config[:skin])),
                Rack::File.new(File.join(config[:skins_directory], 'base'))
              ])
            end
        
            map('/') { run Adyen::SkinBuilder::SkeletonAdapter.new(config[:skins_directory], config[:skin]) }
          end
        end
      end
    end
  end
end
