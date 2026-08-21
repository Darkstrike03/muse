# Third-party licenses

Muse is licensed under the Apache License, Version 2.0 (see `LICENSE`).
It builds on the following open-source software. Where a full license text
is not reproduced here, it is available at the linked source.

## Runtime dependencies

### Tor — https://gitlab.torproject.org/tpo/core/tor
Copyright (c) The Tor Project, Inc.
License: BSD 3-Clause ("New" or "Revised") plus the Tor patent grant.

```
Copyright (c) 2001-2004, Roger Dingledine
Copyright (c) 2004-2007, Roger Dingledine, Nick Mathewson
Copyright (c) 2007-2026, The Tor Project, Inc.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

    * Neither the names of the copyright owners nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

The Windows releases of Muse bundle Tor binaries downloaded from the
official Tor Project distribution via `tool/setup_tor.ps1`.

### tor-android / jtorctl — https://github.com/guardianproject/tor-android
Copyright (c) The Guardian Project.
`info.guardianproject:tor-android:0.4.8.22`,
`info.guardianproject:jtorctl:0.4.5.7`.
Licensed under the BSD 3-Clause License (same text as Tor above).

### media_kit — https://github.com/media-kit/media-kit
Copyright (c) 2022 Abdelrahman Abdelrazek
License: MIT

```
MIT License

Copyright (c) 2022 Abdelrahman Abdelrazek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

media_kit embeds libmpv (LGPL-2.1+; built as a dynamically linked library by
`media_kit_libs_audio`, which preserves your LGPL right to replace it).

### Flutter — https://flutter.dev
Copyright 2014 The Chromium Authors. Copyright (c) Google, Inc. and
affiliates. License: BSD 3-Clause (same shape as the Tor text above).
https://github.com/flutter/flutter/blob/main/LICENSE

## Dart packages (pub.dev)

All Dart packages used by Muse carry permissive licenses (BSD-3, MIT, or
Apache-2.0). The complete list with versions resolved for any given build is
in `pubspec.lock`; notable direct dependencies:

| Package | Use | License |
|---|---|---|
| flutter_riverpod | state management | MIT |
| go_router | navigation | BSD-3 |
| file_picker | music folder picking | MIT |
| audio_metadata_reader | tag scanning | MIT |
| image_picker | playlist artwork | Apache-2.0 |
| sqflite / sqflite_common_ffi | SQLite storage | MIT |
| qr_flutter / mobile_scanner | pairing codes | MIT / Apache-2.0 |
| shelf / shelf_router | share server HTTP | BSD-3 |
| path_provider | platform directories | BSD-3 |
| permission_handler | storage access on Android | MIT |
| package_info_plus / url_launcher | update checker | BSD-3 |
| shared_preferences | settings persistence | BSD-3 |

## Typefaces

### Cinzel Decorative — Copyright (c) Natanael Gama
### Inter — Copyright (c) The Inter Project Authors
Both are licensed under the SIL Open Font License, Version 1.1:
https://openfontlicense.org/

The fonts are embedded in application assets (`lib/assets/fonts/`) under the
OFL's font-redistribution terms; they remain under OFL when redistributed
with Muse.
