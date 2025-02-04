require 'open-uri'
require 'nokogiri'

class WordOfTheDayProvider
  @providers = []

  def fetch
    doc = get_doc
    word = fetch_word(doc)
    word_definitions = fetch_definitions(doc, word)

    word_definitions[:word] = (word.nil? or word.empty?) ? '>>Word not found<<' : word
    word_definitions[:definition] = '>>Definition not found<<' if word_definitions[:definition].nil? or word_definitions[:definition].empty?
    word_definitions[:source] = src_desc unless word_definitions[:source]
    word_definitions.compact
  rescue => e
    {
      word: ">>#{e.class.to_s}<<",
      definition: ">>#{e.message}<<",
      source: src_desc
    }
  end

  def fetch_word(doc)
    raise NotImplementedError, "Subclasses must implement `fetch_word`"
  end

  def fetch_definitions(doc, word)
    raise NotImplementedError, "Subclasses must implement `fetch_definitions`"
  end

  def src_desc
    raise NotImplementedError, "Subclasses must implement `src_desc`"
  end

  def get_doc
    raise NotImplementedError, "Subclasses must implement `get_doc`"
  end

  def self.providers
    self.leaf_classes(WordOfTheDayProvider)
  end

  def self.leaf_classes(klass)
    subclasses = klass.subclasses

    if subclasses.empty?
      [klass]
    else
      subclasses.flat_map { |subclass| leaf_classes(subclass) }
    end
  end

end

#Provides definition from HTML and XML for given url
class MarkupDocumentProvider < WordOfTheDayProvider

  def url
    raise NotImplementedError, "Subclasses must implement `url`"
  end

  def src_desc
    URI.parse(url).host
  end

  def get_doc
    response = URI.open(url)
    content_type = response.content_type

    if content_type.include?('xml')
      Nokogiri::XML(response)
    elsif content_type.include?('html')
      Nokogiri::HTML(response)
    else
      raise "Unsupported content type: #{content_type}"
    end
  end

end
