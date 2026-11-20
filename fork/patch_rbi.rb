# frozen_string_literal: true

# Patches the SDK's shipped RBI files so that Sorbet 0.6.x (as used by applications that run `srb tc` over a Tapioca-generated
# gem RBI, which merges the shipped RBIs) accepts them. Run by fork/package_gem.rb on the copy of rbi/ that goes into the gems,
# so the repository's rbi/ stays upstream's.
#
#   1. The generated protobuf RBIs name Google::Protobuf::Map and Google::Protobuf::RepeatedField without type arguments, but
#      both are generic, so Sorbet rejects them ("Generic class without type arguments").
#   2. Workflow.upsert_memo is declared with `overload` signatures that take keyword arguments, which Sorbet rejects
#      ("Overloaded functions cannot have keyword arguments"). The general signature that follows them is kept.
#
# Usage: ruby fork/patch_rbi.rb RBI_DIR
rbi_dir = ARGV.fetch(0)
patched_files = 0

Dir[File.join(rbi_dir, '**/*.rbi')].each do |path|
  content = File.read(path)
  patched =
    content
    .gsub(/Google::Protobuf::Map(?!\[)/, 'Google::Protobuf::Map[T.untyped, T.untyped]')
    .gsub(/Google::Protobuf::RepeatedField(?!\[)/, 'Google::Protobuf::RepeatedField[T.untyped]')
    .gsub(/^ *sig do\n *overload\.params\(\n.*?\n *\)\.void\n *end\n/m, '')
  next if patched == content

  File.write(path, patched)
  patched_files += 1
end

warn "patched #{patched_files} RBI files in #{rbi_dir}"
