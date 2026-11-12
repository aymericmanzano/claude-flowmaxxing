import Foundation

/// Textes de l'interface en anglais, français, espagnol et allemand. La langue suit les
/// préférences du système (première langue prise en charge), avec l'anglais par défaut.
/// Pour ajouter une langue : une colonne de plus dans chaque entrée de `table`.
enum L {
    static let supported = ["en", "fr", "es", "de"]

    static let lang: String = {
        for id in Locale.preferredLanguages {
            let code = String(id.prefix(2))
            if supported.contains(code) { return code }
        }
        return "en"
    }()

    static var isFrench: Bool { lang == "fr" }

    /// Texte traduit ; les `%@` et `%d` se remplissent avec `args`.
    static func s(_ key: String, _ args: CVarArg...) -> String {
        let row = table[key] ?? [:]
        let format = row[lang] ?? row["en"] ?? key
        return args.isEmpty ? format : String(format: format, arguments: args)
    }

    private static let table: [String: [String: String]] = [
        "tab.music": ["en": "Music", "fr": "Musique", "es": "Música", "de": "Musik"],
        "help.refresh": ["en": "Refresh", "fr": "Actualiser", "es": "Actualizar", "de": "Aktualisieren"],
        "help.quit": ["en": "Quit Claude Flowmaxxing", "fr": "Quitter Claude Flowmaxxing",
                      "es": "Salir de Claude Flowmaxxing", "de": "Claude Flowmaxxing beenden"],

        "sessions.none": ["en": "No open session", "fr": "Aucune session ouverte",
                          "es": "Ninguna sesión abierta", "de": "Keine offene Sitzung"],
        "sessions.one": ["en": "1 open session", "fr": "1 session ouverte",
                         "es": "1 sesión abierta", "de": "1 offene Sitzung"],
        "sessions.many": ["en": "%d open sessions", "fr": "%d sessions ouvertes",
                          "es": "%d sesiones abiertas", "de": "%d offene Sitzungen"],
        "sessions.busy": ["en": "%@, running: %@", "fr": "%@, en cours : %@",
                          "es": "%@, en curso: %@", "de": "%@, aktiv: %@"],

        "quota.5h": ["en": "5 hours", "fr": "5 heures", "es": "5 horas", "de": "5 Stunden"],
        "quota.7d": ["en": "7 days", "fr": "7 jours", "es": "7 días", "de": "7 Tage"],
        "quota.5h.short": ["en": "5h", "fr": "5 h", "es": "5 h", "de": "5 Std"],
        "quota.7d.short": ["en": "7d", "fr": "7 j", "es": "7 d", "de": "7 T"],
        "quota.reset": ["en": "resets in %@", "fr": "remise à zéro dans %@",
                        "es": "se reinicia en %@", "de": "zurückgesetzt in %@"],
        "quota.badge": ["en": "in notch", "fr": "dans l'encoche", "es": "en el notch", "de": "in der Notch"],
        "quota.shown": ["en": "Shown in the notch", "fr": "Affiché dans l'encoche",
                        "es": "Mostrado en el notch", "de": "In der Notch angezeigt"],
        "quota.clickToShow": ["en": "Click to show in the notch", "fr": "Cliquer pour afficher dans l'encoche",
                              "es": "Haz clic para mostrarlo en el notch", "de": "Klicken, um es in der Notch anzuzeigen"],
        "quota.cycle": ["en": "%@: click to switch between 5 hours, 7 days and Fable",
                        "fr": "%@ : cliquer pour passer à 5 heures, 7 jours ou Fable",
                        "es": "%@: haz clic para cambiar entre 5 horas, 7 días y Fable",
                        "de": "%@: klicken für 5 Stunden, 7 Tage oder Fable"],

        "cost.today": ["en": "Today's cost, local", "fr": "Coût du jour, en local",
                       "es": "Coste de hoy, local", "de": "Kosten heute, lokal"],
        "cost.projection": ["en": "about %@ by tonight", "fr": "environ %@ d'ici ce soir",
                            "es": "unos %@ esta noche", "de": "etwa %@ bis heute Abend"],
        "cost.dayOver": ["en": "day over", "fr": "journée terminée", "es": "día terminado", "de": "Tag vorbei"],
        "cost.computing": ["en": "calculating", "fr": "calcul en cours", "es": "calculando", "de": "wird berechnet"],
        "cost.week": ["en": "7-day cost, local", "fr": "Coût sur 7 jours, en local",
                      "es": "Coste en 7 días, local", "de": "Kosten 7 Tage, lokal"],
        "cost.apiRates": ["en": "at public API rates", "fr": "au tarif public de l'API",
                          "es": "a precios públicos de la API", "de": "zu öffentlichen API-Preisen"],
        "model.title": ["en": "Top model", "fr": "Modèle principal", "es": "Modelo principal", "de": "Hauptmodell"],
        "model.none": ["en": "no data", "fr": "aucune donnée", "es": "sin datos", "de": "keine Daten"],
        "model.share": ["en": "%@ of spend over 7 days", "fr": "%@ des dépenses sur 7 jours",
                        "es": "%@ del gasto en 7 días", "de": "%@ der Ausgaben in 7 Tagen"],

        "credits.title": ["en": "Extra usage credits", "fr": "Crédits supplémentaires",
                          "es": "Créditos adicionales", "de": "Zusätzliche Credits"],
        "credits.off": ["en": "Off", "fr": "Désactivés", "es": "Desactivados", "de": "Deaktiviert"],
        "credits.capOf": ["en": "%@ limit reached", "fr": "plafond de %@ atteint",
                          "es": "límite de %@ alcanzado", "de": "Limit von %@ erreicht"],
        "credits.cap": ["en": "limit reached", "fr": "plafond atteint", "es": "límite alcanzado", "de": "Limit erreicht"],
        "credits.pctOf": ["en": "%@ of the %@ limit", "fr": "%@ du plafond de %@",
                          "es": "%@ del límite de %@", "de": "%@ des Limits von %@"],
        "credits.of": ["en": "of %@", "fr": "sur %@", "es": "de %@", "de": "von %@"],

        "music.closed": ["en": "Spotify, Music and VLC are closed. The buttons control the active music app.",
                         "fr": "Spotify, Musique et VLC sont fermés. Les boutons pilotent l'app de musique active.",
                         "es": "Spotify, Música y VLC están cerrados. Los botones controlan la app de música activa.",
                         "de": "Spotify, Musik und VLC sind geschlossen. Die Tasten steuern die aktive Musik-App."],
        "music.permission": ["en": "Allow Claude Flowmaxxing to control %@: System Settings, Privacy & Security, Automation.",
                             "fr": "Autorise Claude Flowmaxxing à piloter %@ : Réglages Système, Confidentialité et sécurité, Automatisation.",
                             "es": "Permite que Claude Flowmaxxing controle %@: Ajustes del Sistema, Privacidad y seguridad, Automatización.",
                             "de": "Erlaube Claude Flowmaxxing, %@ zu steuern: Systemeinstellungen, Datenschutz & Sicherheit, Automation."],
        "music.nothing": ["en": "Nothing playing.", "fr": "Aucun morceau en cours.",
                          "es": "No suena nada.", "de": "Es läuft nichts."],
        "player.music": ["en": "Music", "fr": "Musique", "es": "Música", "de": "Musik"],

        "toast.finished": ["en": "finished", "fr": "a terminé", "es": "ha terminado", "de": "ist fertig"],

        "err.noToken": ["en": "Claude Code token not found. Sign in with claude in the terminal.",
                        "fr": "Jeton Claude Code introuvable. Connecte-toi avec claude dans le terminal.",
                        "es": "No se encuentra el token de Claude Code. Inicia sesión con claude en la terminal.",
                        "de": "Claude-Code-Token nicht gefunden. Melde dich mit claude im Terminal an."],
        "err.notSaved": ["en": "Token renewed but not saved. Run claude, then /login in the terminal.",
                         "fr": "Jeton renouvelé mais non enregistré. Lance claude puis /login dans le terminal.",
                         "es": "Token renovado pero no guardado. Ejecuta claude y luego /login en la terminal.",
                         "de": "Token erneuert, aber nicht gespeichert. Starte claude und dann /login im Terminal."],
        "err.refused": ["en": "Renewal refused. Run claude, then /login in the terminal.",
                        "fr": "Renouvellement refusé. Lance claude puis /login dans le terminal.",
                        "es": "Renovación rechazada. Ejecuta claude y luego /login en la terminal.",
                        "de": "Erneuerung abgelehnt. Starte claude und dann /login im Terminal."],
        "err.renewLater": ["en": "Can't renew the token right now, retrying in 5 min.",
                           "fr": "Renouvellement du jeton impossible pour l'instant, nouvel essai dans 5 min.",
                           "es": "No se puede renovar el token ahora, nuevo intento en 5 min.",
                           "de": "Token kann gerade nicht erneuert werden, neuer Versuch in 5 Min."],
        "err.offline": ["en": "No connection.", "fr": "Pas de connexion.", "es": "Sin conexión.", "de": "Keine Verbindung."],
        "err.denied": ["en": "Anthropic refused the connection. Run claude, then /login in the terminal.",
                       "fr": "Connexion refusée par Anthropic. Lance claude puis /login dans le terminal.",
                       "es": "Anthropic rechazó la conexión. Ejecuta claude y luego /login en la terminal.",
                       "de": "Anthropic hat die Verbindung abgelehnt. Starte claude und dann /login im Terminal."],
        "err.rate": ["en": "Anthropic is limiting requests, retrying in %d min.",
                     "fr": "Anthropic limite les appels, nouvel essai dans %d min.",
                     "es": "Anthropic limita las peticiones, nuevo intento en %d min.",
                     "de": "Anthropic begrenzt die Anfragen, neuer Versuch in %d Min."],
        "err.unexpected": ["en": "Unexpected response (%d).", "fr": "Réponse inattendue (%d).",
                           "es": "Respuesta inesperada (%d).", "de": "Unerwartete Antwort (%d)."],
        "err.unreadable": ["en": "Unreadable response.", "fr": "Réponse illisible.",
                           "es": "Respuesta ilegible.", "de": "Unlesbare Antwort."],

        "dur.dh": ["en": "%dd %dh", "fr": "%d j %d h", "es": "%d d %d h", "de": "%d T %d Std."],
        "dur.hm": ["en": "%dh %dm", "fr": "%d h %d min", "es": "%d h %d min", "de": "%d Std. %d Min."],
        "dur.m": ["en": "%dm", "fr": "%d min", "es": "%d min", "de": "%d Min."],
    ]
}
