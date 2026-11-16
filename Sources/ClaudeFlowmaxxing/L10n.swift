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

        "tab.board": ["en": "Board", "fr": "Tableau", "es": "Panel", "de": "Übersicht"],
        "help.settings": ["en": "Settings", "fr": "Réglages", "es": "Ajustes", "de": "Einstellungen"],

        "board.5h": ["en": "5-hour window", "fr": "Fenêtre de 5 heures", "es": "Ventana de 5 horas", "de": "5-Stunden-Fenster"],
        "board.week": ["en": "Week", "fr": "Semaine", "es": "Semana", "de": "Woche"],
        "board.left": ["en": "left", "fr": "restants", "es": "restante", "de": "übrig"],
        "board.ahead": ["en": "%@ pts ahead", "fr": "%@ pts d'avance", "es": "%@ pts de ventaja", "de": "%@ Pkt. voraus"],
        "board.behind": ["en": "%@ pts behind", "fr": "%@ pts de retard", "es": "%@ pts de retraso", "de": "%@ Pkt. zurück"],
        "board.resetAt": ["en": "resets %@ at %@", "fr": "remise à zéro %@ à %@", "es": "se reinicia el %@ a las %@", "de": "Reset %@ um %@"],
        "board.budget": ["en": "budget %@ a day", "fr": "budget %@ par jour", "es": "presupuesto %@ al día", "de": "Budget %@ pro Tag"],
        "board.now": ["en": "now", "fr": "maintenant", "es": "ahora", "de": "jetzt"],
        "board.locked": ["en": "Locked", "fr": "Bloqué", "es": "Bloqueado", "de": "Gesperrt"],
        "board.empty": ["en": "empty %@ %@", "fr": "vide %@ %@", "es": "vacío %@ %@", "de": "leer %@ %@"],
        "board.atEnd": ["en": "about %@ at reset", "fr": "environ %@ à la fin", "es": "unos %@ al final", "de": "etwa %@ am Ende"],
        "board.usage": ["en": "What used it this week", "fr": "Ce qui consomme cette semaine",
                        "es": "Qué consumió esta semana", "de": "Verbrauch diese Woche"],
        "board.tokens": ["en": "tokens this week", "fr": "tokens cette semaine", "es": "tokens esta semana", "de": "Tokens diese Woche"],
        "board.api": ["en": "API value", "fr": "valeur API", "es": "valor API", "de": "API-Wert"],
        "board.calls": ["en": "calls, %@ on %@", "fr": "appels, dont %@ sur %@", "es": "llamadas, %@ con %@", "de": "Aufrufe, %@ mit %@"],
        "board.callsOnly": ["en": "calls", "fr": "appels", "es": "llamadas", "de": "Aufrufe"],
        "board.hover": ["en": "%@: %@ left", "fr": "%@ : %@ restants", "es": "%@: %@ restante", "de": "%@: %@ übrig"],
        "board.hoverForecast": ["en": "%@: about %@ left (forecast)", "fr": "%@ : environ %@ restants (prévision)",
                                "es": "%@: unos %@ restante (previsión)", "de": "%@: etwa %@ übrig (Prognose)"],
        "board.aheadHelp": ["en": "You have used less than an even pace would", "fr": "Tu consommes moins vite qu'un rythme régulier",
                            "es": "Consumes menos que a ritmo regular", "de": "Du verbrauchst weniger als bei gleichmäßigem Tempo"],
        "board.behindHelp": ["en": "You have used more than an even pace would", "fr": "Tu consommes plus vite qu'un rythme régulier",
                             "es": "Consumes más que a ritmo regular", "de": "Du verbrauchst mehr als bei gleichmäßigem Tempo"],
        "board.root": ["en": "Root", "fr": "Racine", "es": "Raíz", "de": "Stamm"],
        "board.others": ["en": "Others", "fr": "Autres", "es": "Otros", "de": "Andere"],
        "board.nodata": ["en": "No usage this week yet", "fr": "Aucune consommation cette semaine",
                         "es": "Sin consumo esta semana", "de": "Noch kein Verbrauch diese Woche"],
        "num.billion": ["en": "B", "fr": " Md", "es": " mil M", "de": " Mrd."],
        "num.million": ["en": "M", "fr": " M", "es": " M", "de": " Mio."],

        "alert.line": ["en": "Week runs out %@ around %@ at this pace, budget %@ a day",
                       "fr": "Semaine vide %@ vers %@ à ce rythme, budget %@ par jour",
                       "es": "La semana se agota el %@ hacia las %@ a este ritmo, presupuesto %@ al día",
                       "de": "Woche leer am %@ gegen %@ bei diesem Tempo, Budget %@ pro Tag"],

        "set.weekly": ["en": "Notify below 50%, 25% and 10% of the week", "fr": "Notification sous 50%, 25% et 10% de la semaine",
                       "es": "Avisar por debajo del 50%, 25% y 10% de la semana", "de": "Hinweis unter 50%, 25% und 10% der Woche"],
        "set.projectionAlert": ["en": "Warn if the week runs out before the reset", "fr": "Prévenir si la semaine finit avant le renouvellement",
                                "es": "Avisar si la semana se agota antes del reinicio", "de": "Warnen, wenn die Woche vor dem Reset endet"],
        "set.fiveAlert": ["en": "Warn when the 5-hour window drops below 10%", "fr": "Prévenir quand la fenêtre de 5 heures passe sous 10%",
                          "es": "Avisar cuando la ventana de 5 horas baje del 10%", "de": "Warnen, wenn das 5-Stunden-Fenster unter 10% fällt"],
        "set.projection": ["en": "Projection", "fr": "Projection", "es": "Proyección", "de": "Prognose"],
        "set.projection.sub": ["en": "pace used to predict the end", "fr": "rythme pris en compte",
                               "es": "ritmo usado para prever", "de": "Tempo für die Vorhersage"],
        "set.mode.week": ["en": "Week", "fr": "Semaine", "es": "Semana", "de": "Woche"],
        "set.login": ["en": "Open at login", "fr": "Lancer au démarrage du Mac", "es": "Abrir al iniciar sesión", "de": "Beim Anmelden öffnen"],
        "set.login.help": ["en": "Available once the app is in Applications", "fr": "Disponible une fois l'app dans Applications",
                           "es": "Disponible cuando la app está en Aplicaciones", "de": "Verfügbar, sobald die App in Programme liegt"],
        "set.credit": ["en": "Claude Flowmaxxing %@, by Aymeric Manzano", "fr": "Claude Flowmaxxing %@, par Aymeric Manzano",
                       "es": "Claude Flowmaxxing %@, por Aymeric Manzano", "de": "Claude Flowmaxxing %@, von Aymeric Manzano"],

        "notif.week.title": ["en": "Claude Code week", "fr": "Semaine Claude Code", "es": "Semana de Claude Code", "de": "Claude-Code-Woche"],
        "notif.week": ["en": "%@ of your week left", "fr": "Il te reste %@ de ta semaine", "es": "Te queda %@ de tu semana", "de": "Noch %@ deiner Woche übrig"],
        "notif.projection.title": ["en": "Your week will run out early", "fr": "Ta semaine va finir trop tôt",
                                   "es": "Tu semana se agotará antes", "de": "Deine Woche endet zu früh"],
        "notif.projection": ["en": "At this pace it runs out %@ around %@. Stay under %@ a day.",
                             "fr": "À ce rythme, elle s'épuise %@ vers %@. Reste sous %@ par jour.",
                             "es": "A este ritmo se agota el %@ hacia las %@. Quédate por debajo de %@ al día.",
                             "de": "Bei diesem Tempo ist sie am %@ gegen %@ leer. Bleib unter %@ pro Tag."],
        "notif.five.title": ["en": "5-hour window", "fr": "Fenêtre de 5 heures", "es": "Ventana de 5 horas", "de": "5-Stunden-Fenster"],
        "notif.five": ["en": "Less than 10% left", "fr": "Il te reste moins de 10%", "es": "Te queda menos del 10%", "de": "Weniger als 10% übrig"],
    ]
}
