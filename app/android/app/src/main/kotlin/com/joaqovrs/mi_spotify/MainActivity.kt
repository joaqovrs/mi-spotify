package com.joaqovrs.mi_spotify

import com.ryanheise.audioservice.AudioServiceActivity

// Hereda de AudioServiceActivity (y no de FlutterActivity) para que la
// reproducción sobreviva cuando la app pasa a segundo plano.
class MainActivity : AudioServiceActivity()
