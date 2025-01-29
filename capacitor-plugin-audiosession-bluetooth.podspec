Pod::Spec.new do |s|
  s.name = 'CapacitorPluginAudiosessionBluetooth'
  s.version = '0.0.1'
  s.summary = 'Audio session management with Bluetooth auto-switching'
  s.license = 'MIT'
  s.homepage = 'https://github.com/your-username/capacitor-plugin-audiosession-bluetooth'
  s.author = 'Your Name'
  s.source = { :git => 'https://github.com/your-username/capacitor-plugin-audiosession-bluetooth', :tag => s.version.to_s }
  s.source_files = 'ios/Plugin/**/*.{swift,h,m}'
  s.ios.deployment_target = '13.0'
  s.dependency 'Capacitor'
end 