# DeepL.cr

[![CI](https://github.com/kojix2/deepl.cr/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/deepl.cr/actions/workflows/test.yml)
[![Docs Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://kojix2.github.io/deepl.cr/)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fapi%2Fbadge%2Flines%3Furl%3Dhttps%3A%2F%2Fgithub.com%2Fkojix2%2Fdeepl.cr%2F)](https://tokei.kojix2.net/analyze?url=https%3A%2F%2Fgithub.com%2Fkojix2%2Fdeepl.cr%2F)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/kojix2/deepl.cr)

Crystal library for the [DeepL language translation API](https://www.deepl.com/pro-api/).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     deepl:
       github: kojix2/deepl.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "deepl"

# Translate text
t = DeepL::Translator.new(auth_key: "YOUR_AUTH_KEY")
result = t.translate_text("こんにちは、世界！", target_lang: "EN")
puts result.first.text # => "Hello, world!"

# Translate document
t = DeepL::Translator.new(auth_key: "YOUR_AUTH_KEY")
t.translate_document("path/to/document.pdf", target_lang: "EN")
# Save to file (default: "path/to/document_EN.pdf")

# Rephrase text (improve writing)
t = DeepL::Translator.new(auth_key: "YOUR_AUTH_KEY")
result = t.rephrase_text("I have went to the store yesterday.")
puts result[0].text # => "I went to the store yesterday."

# Voice realtime (v3 surface)
t = DeepL::Translator.new(auth_key: "YOUR_AUTH_KEY")
voice = t.get_voice_streaming_url(
  source_media_content_type: "audio/ogg; codecs=opus",
  source_language: "en",
  source_language_mode: "auto",
  target_languages: ["de", "fr"]
)
puts voice.streaming_url
```

### Glossaries, document options, and Translation Memory

Use an ID for automation. Name-based helpers are conveniences only: a name
must resolve to exactly one glossary, otherwise the library raises
`AmbiguousGlossaryNameError` and asks the caller to select an ID explicitly.

Text and document translation can use up to five glossary IDs. Supplying
`glossary_ids` requires `source_lang` and cannot be combined with
`glossary_id` or `glossary_name`.

```crystal
result = t.translate_text(
  "Hello",
  target_lang: "DE",
  source_lang: "EN",
  glossary_ids: ["glossary-id-1", "glossary-id-2"],
)

t.translate_document(
  "path/to/document.pdf",
  target_lang: "DE",
  source_lang: "EN",
  glossary_ids: ["glossary-id-1", "glossary-id-2"],
  style_id: "style-id",
  translation_memory_id: "translation-memory-id",
  translation_memory_threshold: 75,
)
```

On the v3 surface, Translation Memory reads are available without adding a
write or job-management layer:

```crystal
memory = t.get_translation_memory("translation-memory-id")
segments = t.list_translation_memory_segments("translation-memory-id", page_size: 100)
```

All non-2xx HTTP responses raise a `DeepL::DeepLError`. When the service
provides an `X-Trace-ID`, it is available as `error.trace_id` for support
requests.

See [documentation](https://kojix2.github.io/deepl.cr/).

### Environment Variables

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>DEEPL_AUTH_KEY</td>
      <td>DeepL API authentication key</td>
    </tr>
    <tr>
      <td>DEEPL_TARGET_LANG</td>
      <td>Default target language</td>
    </tr>
    <tr>
      <td>DEEPL_USER_AGENT</td>
      <td>User-Agent</td>
    </tr>
  </tbody>
</table>

- When the environment variable `DEEPL_TARGET_LANG` is set, the method `DeepL::Translator#guess_target_language` will prioritize the language defined in `DEEPL_TARGET_LANG`.
- However, please note that this does not directly affect translation methods like `translate_text`.

## Development

- Pull requests are welcome.
- If you want to take over the project and become the owner, please submit your request with a pull request.

- [DeepL OpenAPI Specification](https://github.com/DeepLcom/openapi)

### API version selection and endpoint routing

This library currently supports both v2 and v3 API families.

- The API surface is selected at compile time. The library loads v2 when `-Ddeepl_v2` is set or `DEEPL_API_VERSION=v2`; otherwise it loads v3 when `-Ddeepl_v3` or `DEEPL_API_VERSION=v3` is set, and defaults to v3.
- In the v2 surface, translation, document, usage, language, rephrase, admin, and glossary methods use v2 endpoints.
- In the v3 surface, translation, document, usage, language, rephrase, and admin methods remain on v2 endpoints, while multilingual glossary, style rules, Translation Memory, and voice realtime use v3 endpoints. Multilingual glossary language pairs are the intentional `/v2` exception.

Each endpoint determines its own `/v2` or `/v3` path; surface selection never rewrites a request URL. `Translator#server_url` remains a compatibility accessor and may include the legacy `DEEPL_API_VERSION` suffix, but internal requests use a normalized base URL. Custom URLs ending in `/v2` or `/v3` are accepted and normalized for internal routing.

### Run tests (v2 / v3)

- v2 (compile-time flag):
  ```bash
  crystal spec -Ddeepl_v2
  ```
- v3 (compile-time flag):
  ```bash
  crystal spec -Ddeepl_v3
  ```
- v2 (environment variable):
  ```bash
  DEEPL_API_VERSION=v2 crystal spec
  ```
- v3 (environment variable):
  ```bash
  DEEPL_API_VERSION=v3 crystal spec
  ```

Note: The library surface is also switched by the same conditions.

## Use case

- [DeepL CLI](https://github.com/kojix2/deepl-cli)

## Contributing

1. Fork it (<https://github.com/kojix2/deepl.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# License

MIT
