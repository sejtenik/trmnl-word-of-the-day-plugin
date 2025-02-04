require 'open-uri'
require 'nokogiri'
require 'json'
require 'dotenv/load'
require 'addressable/uri'

class WordOfTheDayParser
  def fetch
    html = URI.open(url)
    doc = Nokogiri::HTML(html)
    result = parse(doc)

    result[:word] = '>>Word not found<<' if result[:word].nil? or result[:word].empty?
    result[:definition] = '>>Definition not found<<' if result[:definition].nil? or result[:definition].empty?
    result[:source] = URI.parse(url).host
    result
  rescue => e
    {
      word: ">>#{e.class.to_s}<<",
      definition: ">>#{e.message}<<",
      source: url
    }
  end

  protected

  def parse(doc)
    raise NotImplementedError, "Subclasses must implement `parse`"
  end

  def url
    raise NotImplementedError, "Subclasses must implement `url`"
  end

end

class WordOfTheDayFactory
  def self.parsers
    ObjectSpace.each_object(Class)
               .select { |klass| klass < WordOfTheDayParser }
               .map(&:new)
  end
end

class DictionaryComParser < WordOfTheDayParser
  def parse(doc)
    word = doc.at_css(".otd-item-headword__word h1.js-fit-text")&.text&.strip
    pronunciation = doc.at_css(".otd-item-headword__ipa")&.text&.strip
    pronunciation.gsub!(/^\[|\]$/, '').strip! if pronunciation
    part_of_speech = doc.at_css(".otd-item-headword__pos p span.italic")&.text&.strip
    definition = doc.at_css(".otd-item-headword__pos p:not(.italic) + p")&.text&.strip

    {
      word: word,
      part_of_speech: part_of_speech,
      pronunciation: pronunciation,
      definition: definition,
    }
  end

  def url
    "https://www.dictionary.com/e/word-of-the-day/"
  end

end


class DikiParser < WordOfTheDayParser
  def parse(doc)
    word_box = doc.at_css(".wordofthedaybox")
    word = word_box.at_css(".hws .hw a").text.strip
    part_of_speech = word_box.at_css(".partOfSpeech").text.strip
    meanings = doc.css('ol.foreignToNativeMeanings li').map do |li|
      li.xpath(".//span[@class='hw'] | .//span[@class='hwcomma']").map(&:text).join('; ').strip
    end.join(", ")


    first_example = word_box.at_css(".exampleSentence")
    example= ''

    if first_example
      english_example = first_example.text.strip.split("\n").first.strip
      polish_translation = first_example.at_css(".exampleSentenceTranslation")&.text&.strip

      example = "#{english_example} #{polish_translation}"
    end

    {
      word: word,
      part_of_speech: part_of_speech,
      definition: meanings,
      example: example,
    }
  end

  def url
    "https://www.diki.pl/dictionary/word-of-the-day"
  end

end

class WsjpParser < WordOfTheDayParser
  def parse(doc)
    day_word_box = doc.at_css(".day-word-box")
    word = day_word_box.at_css("h4").text.strip
    qualifier = day_word_box.at_css(".kwalifikator")&.text&.strip
    definition = day_word_box.css("span").last.text.strip

    {
      word: word,
      qualifier: qualifier,
      definition: definition,
    }
  end

  def url
    "https://wsjp.pl"
  end

end

class MerriamParser < WordOfTheDayParser
  def parse(doc)
    word_element = doc.at_css('.word-header-txt')
    word = word_element ? word_element.text.strip : "Nie znaleziono słowa"

    part_of_speech_element = doc.at_css('.main-attr')
    part_of_speech = part_of_speech_element ? part_of_speech_element.text.strip : "Nie znaleziono części mowy"

    pronunciation_element = doc.at_css('.word-syllables')
    pronunciation = pronunciation_element ? pronunciation_element.text.strip : "Nie znaleziono wymowy"

    definition_container = doc.at_css(".wod-definition-container")

    definition = []
    definition_container.css("p").each do |p|
      break if p.text.strip.start_with?("//")
      definition << p.text.strip
    end

    definition = definition.join(" ").strip

    example = definition_container.css("p").find { |p| p.text.strip.start_with?("//") }
                &.inner_html&.gsub("//", "")&.strip
    {
      word: word,
      part_of_speech: part_of_speech,
      pronunciation: pronunciation,
      definition: definition,
      example: example,
    }
  end

  def url
    'https://www.merriam-webster.com/word-of-the-day'
  end

end

class BritannicaParser < WordOfTheDayParser
  def parse(doc)
    word = doc.at_css(".hw_d .hw_txt, .hw_m .hw_txt")&.text&.strip

    pronunciation = doc.at_css(".hpron_word")&.text&.strip
    pronunciation.gsub!(/^\//, '').gsub!(/\/$/, '') if pronunciation
    part_of_speech = doc.at_css(".fl")&.text&.strip
    definition = doc.at_css(".midb:first-of-type .midbt p")&.text&.strip.sub(/^\d+ /, '').sub(/^:\s*/, '')
    example = doc.at_css(".midb:first-of-type .vib .vis .vi p")&.text&.strip

    {
      word: word,
      part_of_speech: part_of_speech,
      pronunciation: pronunciation,
      example: example,
      definition: definition,
    }
  end

  def url
    "https://www.britannica.com/dictionary/eb/word-of-the-day"
  end

end


class CambridgeParser < WordOfTheDayParser
  def parse(doc)
    word = doc.at_css(".wotd-hw a")&.text&.strip

    pronunciation = doc.at_css(".ipa.dipa")&.text&.strip
    pronunciation.gsub!(/^\//, '').gsub!(/\/$/, '') if pronunciation

    definition = doc.css("p").find { |p|
      p.next_element&.name == "a" && p.next_element["href"]&.include?(word.gsub(" ", "-"))
    }&.text&.strip

    {
      word: word,
      pronunciation: pronunciation,
      definition: definition,
    }
  end

  def url
    "https://dictionary.cambridge.org/"
  end

end

class WiktionaryParser < WordOfTheDayParser
  def parse(doc)
    word_element = doc.at_css("#WOTD-rss-title")
    word = word_element&.text&.strip
    part_of_speech = word_element.parent.parent.next_element&.text&.strip
    definition = doc.at_css("#WOTD-rss-description ol li")&.text&.strip

    {
      word: word,
      definition: definition,
      part_of_speech: part_of_speech,
    }
  end

  def url
    "https://en.wiktionary.org/wiki/Wiktionary:Main_Page"
  end

end

class OxfordParser < WordOfTheDayParser
  def parse(doc)
    word_element = doc.at_css(".wotd h3 a")
    word = word_element&.text&.strip
    part_of_speech = doc.at_css(".wotdPos")&.text&.strip
    definition = doc.at_css(".wotdDef")&.text&.strip

    {
      word: word,
      definition: definition,
      part_of_speech: part_of_speech,
    }
  end

  def url
    "https://www.oed.com/"
  end

end

class LongmanParser < WordOfTheDayParser
  def parse(doc)
    word_element = doc.at_css("#wotd .title_entry a")
    word = word_element&.text&.strip
    definition = doc.at_css("#wotd .ldoceEntry .newline a")&.text&.strip

    {
      word: word,
      definition: definition,
    }
  end

  def url
    "https://www.ldoceonline.com/"
  end

end


class PwnParser < WordOfTheDayParser
  def parse(doc)
    day_word_box = doc.at_css(".sjp-slowo-dnia")
    word_link = day_word_box.at_css("a")

    word = word_link.text.strip
    word_url = Addressable::URI.parse(word_link['href']).normalize.to_s

    word_html = URI.open(word_url)
    word_doc = Nokogiri::HTML(word_html)
    definition_text = word_doc.at_css(".znacz").text.strip
    definition_text.force_encoding('UTF-8')
    definition = definition_text.match(/«(.*?)»/)[1]

    {
      word: word,
      definition: definition,
    }
  end

  def url
    "https://sjp.pwn.pl"
  end

end


def send_to_trmnl(data_payload)
  trmnl_webhook_url = "https://usetrmnl.com/api/custom_plugins/#{ENV['TRMNL_PLUGIN_ID']}"

  puts('Send data to trmnl webhook')
  uri = URI(trmnl_webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  headers = {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{ENV['TRMNL_API_KEY']}"
  }

  request = Net::HTTP::Post.new(uri.path, headers)
  request.body = {merge_variables: data_payload}.to_json

  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    current_timestamp = DateTime.now.iso8601
    puts "Tasks sent successfully to TRMNL at #{current_timestamp}"
  else
    puts "Error: #{response.body}"
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  raise
end

############# execution #########

dictionaries = WordOfTheDayFactory.parsers

word_of_the_day = dictionaries[rand(dictionaries.size-1)].fetch

puts word_of_the_day

send_to_trmnl(word_of_the_day)
