# typed: false
# frozen_string_literal: true

# Minimal shim for google-protobuf types referenced by generated proto RBI files.

module Google
  module Protobuf
    module MessageExts
      module ClassMethods; end
    end

    class AbstractMessage; end
    class Descriptor; end
    class EnumDescriptor; end
    class RepeatedField; end
    class Map; end

    class Any; end
    class DoubleValue; end
    class Duration; end
    class Empty; end
    class FieldMask; end
    class Timestamp; end
  end
end
