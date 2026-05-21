Pod::Spec.new do |s|
  s.name             = 'kittentts_flutter'
  s.version          = '0.1.0'
  s.summary          = 'On-device KittenTTS speech synthesis for Flutter.'
  s.description      = 'Flutter SDK for KittenTTS with native CE phonemizer support.'
  s.homepage         = 'https://github.com/KittenML/KittenTTS-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'KittenML' => 'hello@kittenml.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-u,_phonemizer_create'
  }
end
