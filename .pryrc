begin
  require 'amazing_print'
  AmazingPrint.pry!
rescue LoadError => _e
  begin
    require 'awesome_print'
    AwesomePrint.pry!
  rescue LoadError => _e
    puts 'no awesome/amazing_print :('
  end
end
