# frozen_string_literal: true
#
# Copyright 2024-2026 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

load "../ultisel/load/arma.rake" # ...sorry this is not public yet

arma.source_dirs << "lib2"

arma.import arma: "../ultisel", version: nil, build: true,
  include: [
    Ulse.minimum_custom_includes,
    '^ulse/argie.rb$' \
    '|^ulse/ext/module(/attrs)?.rb$' \
    '|^ulse/ext/numeric(/commafy)?.rb$' \
    '|^ulse/ext/object(/(as_grouping|grouping|transform|truthy_falsey))?.rb$' \
    '|^ulse/ext/string(/ellipt)?.rb$' \
    '|^ulse/mixin/asker.rb$'
  ]
