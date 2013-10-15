# Add colorize method to the IO class.

class IO
  def colorize(input, args)
    args = [args] unless args.is_a?(Array)
    colors = {
      black: ["\033[30m", "\033[0m"],
      red: ["\033[31m", "\033[0m"],
      green: ["\033[32m", "\033[0m"],
      brown: ["\033[33m", "\033[0m"],
      blue: ["\033[34m", "\033[0m"],
      magenta: ["\033[35m", "\033[0m"],
      cyan: ["\033[36m", "\033[0m"],
      gray: ["\033[37m", "\033[0m"],
      bg_black: ["\033[40m", "\0330m"],
      bg_red: ["\033[41m", "\033[0m"],
      bg_green: ["\033[42m", "\033[0m"],
      bg_brown: ["\033[43m", "\033[0m"],
      bg_blue: ["\033[44m", "\033[0m"],
      bg_magenta: ["\033[45m", "\033[0m"],
      bg_cyan: ["\033[46m", "\033[0m"],
      bg_gray: ["\033[47m", "\033[0m"],
      bold: ["\033[1m", "\033[22m"],
      reverse_color: ["\033[7m", "\033[27m"]
    }
    return input unless self.isatty

    args.each do |ar|
      next unless colors.key?(ar)
      input = "#{colors[ar].first}#{input}#{colors[ar].last}"
    end

    input
  end
end