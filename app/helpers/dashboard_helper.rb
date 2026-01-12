# frozen_string_literal: true

module DashboardHelper
  # Returns an emoji/icon for common programming languages
  def language_icon(language)
    icons = {
      "Ruby" => "R",
      "JavaScript" => "JS",
      "TypeScript" => "TS",
      "Python" => "Py",
      "Go" => "Go",
      "Rust" => "Rs",
      "Java" => "Ja",
      "C" => "C",
      "C++" => "C++",
      "C#" => "C#",
      "PHP" => "PHP",
      "Swift" => "Sw",
      "Kotlin" => "Kt",
      "HTML" => "H",
      "CSS" => "CSS",
      "SCSS" => "SCSS",
      "Sass" => "Sass",
      "JSON" => "{}",
      "YAML" => "Y",
      "XML" => "<>",
      "Markdown" => "MD",
      "SQL" => "SQL",
      "Shell" => "$",
      "Bash" => "$",
      "Dockerfile" => "D",
      "Vue" => "V",
      "React" => "Re",
      "ERB" => "ERB",
      "HAML" => "HA",
      "Slim" => "Sl",
      "Unknown" => "?"
    }

    icons[language] || language&.first(2)&.upcase || "?"
  end

  # Formats minutes as "X mins" or "X hrs Y mins"
  def format_minutes(minutes)
    return "0 mins" if minutes.nil? || minutes <= 0

    minutes = minutes.to_i

    if minutes < 60
      "#{minutes} #{'min'.pluralize(minutes)}"
    else
      hours = minutes / 60
      remaining_mins = minutes % 60

      if remaining_mins.zero?
        "#{hours} #{'hr'.pluralize(hours)}"
      else
        "#{hours} #{'hr'.pluralize(hours)} #{remaining_mins} #{'min'.pluralize(remaining_mins)}"
      end
    end
  end
end
