-- Standard US International layout: quotes are dead keys, so " + a/o/u
-- produces ä/ö/ü. The input-language plugin still switches base layouts.
hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "intl",
  },
})
