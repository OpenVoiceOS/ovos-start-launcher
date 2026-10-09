#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# OVOS Start protocol v2. Timeless v1 codes are rejected.
# The timestamp is a local expiry check, not a signature or an online revocation.
set -eu
set +x

message() {
  case "${ovos_locale:-en-us}:$1" in
    en-us:bits) printf '%s' 'OVOS needs a 64-bit operating system. No changes were made.';;
    en-us:invalid) printf '%s' 'That setup code is invalid or incomplete. Copy a new command from the wizard.';;
    en-us:expired) printf '%s' 'This setup code expired after one hour. Generate a new code in the wizard.';;
    en-us:future) printf '%s' 'This setup code is future-dated. Check the clock and generate a new code.';;
    en-us:clock) printf '%s' 'The system clock is invalid or unavailable. Correct it before using a setup code.';;
    en-us:regular) printf '%s' 'Run this command from your regular user account, without sudo.';;
    en-us:mac) printf '%s' 'This setup is for a Mac. Run it in Terminal on that Mac.';;
    en-us:linux) printf '%s' 'Run this on your Linux device. On Windows, open Ubuntu in WSL2.';;
    en-us:dependency) printf '%s' 'Install this required tool, then paste your command again:';;
    en-us:existing) printf '%s' 'Move ~/ovos-installer aside first. Your existing checkout has not been changed.';;
    en-us:checking) printf '%s' '1/4 · Checking your device';;
    en-us:download) printf '%s' '2/4 · Downloading the installer';;
    en-us:downloadFailed) printf '%s' 'Download failed. Check your internet connection, then copy a fresh command from the wizard. Your settings were not replaced.';;
    en-us:revision) printf '%s' 'The installer revision could not be verified. Your settings were not replaced.';;
    en-us:backup) printf '%s' 'Previous settings saved to:';;
    en-us:installing) printf '%s' '3/4 · Installing OVOS. This can take a while; follow the installer below.';;
    en-us:installFailed) printf '%s' 'Installation did not complete. Check the error above and /var/log/ovos-installer.log. Your previous settings backup is kept. Ask the community before retrying if you are unsure.';;
    en-us:installReturned) printf '%s' 'The installer step has finished. Check the services and try your voice before treating setup as complete.';;
    en-us:resume) printf '%s' 'After a restart, or to check again, run:';;
    en-us:cancelHint) printf '%s' 'You can type :cancel in any field, or press Ctrl+C, to stop. Completed fields are kept while you correct the next one.';;
    en-us:cancelled) printf '%s' 'Cancelled. The installer has not started and your previous settings are still active.';;
    en-us:required) printf '%s' 'This field is required. Try again, or type :cancel.';;
    en-us:urlError) printf '%s' 'Enter a complete http:// or https:// address with a host. Remove spaces, embedded passwords and fragments.';;
    en-us:haUrl) printf '%s' 'Home Assistant URL: ';;
    en-us:haToken) printf '%s' 'Home Assistant long-lived token: ';;
    en-us:llmLocal) printf '%s' 'Connect your existing local OpenAI-compatible model server.';;
    en-us:llmOnline) printf '%s' 'Connect your chosen online OpenAI-compatible provider. Its usage charges may apply.';;
    en-us:llmUrl) printf '%s' 'OpenAI-compatible API URL: ';;
    en-us:llmModel) printf '%s' 'Model name: ';;
    en-us:llmKey) printf '%s' 'API key (or provider-required placeholder for a keyless local endpoint): ';;
    en-us:bash) printf '%s' 'Install Bash 4+ first.';;
    en-us:health) printf '%s' '4/4 · Checking OVOS services';;
    en-us:servicesOk) printf '%s' 'The expected services are running. This alone does not confirm your microphone or speaker works.';;
    en-us:servicesMissing) printf '%s' 'Some expected services are not running yet. Wait for startup or restart if the installer requested it, then run this check again.';;
    en-us:servicesUnknown) printf '%s' 'Automatic service checks are unavailable here. Installation and voice operation have not been verified.';;
    en-us:checkMenu) printf '%s' 'Next: 1 = try the speaker and microphone, 2 = check services again, Enter = finish later: ';;
    en-us:audioTest) printf '%s' 'Sending a short sound check through OVOS. Listen to your device.';;
    en-us:audioQuestion) printf '%s' 'Did you hear it? 1 = yes, 2 = try again, Enter = finish later: ';;
    en-us:audioOk) printf '%s' 'Speaker test confirmed by you.';;
    en-us:audioFailed) printf '%s' 'The sound check could not reach OVOS. Check service status, volume and your selected audio device.';;
    en-us:voiceIntro) printf '%s' 'Now speak near the microphone. Use your configured wake word if you changed it:';;
    en-us:voicePhrase) printf '%s' 'Hey Mycroft, what time is it?';;
    en-us:voiceQuestion) printf '%s' 'Did OVOS answer correctly? 1 = yes, 2 = try again, Enter = finish later: ';;
    en-us:voiceOk) printf '%s' 'First voice response confirmed by you. Enjoy OVOS!';;
    en-us:incomplete) printf '%s' 'The check is unfinished. You can return to it with the command above.';;
    en-us:customVoice) printf '%s' 'You chose no bundled skills. Try the wake word and a command from a skill you installed; the example time question may not be available.';;
    en-us:hub) printf '%s' 'This is a hub. Check a connected voice satellite to verify microphone and speaker operation.';;
    en-us:help) printf '%s' 'Need a hand? Community chat: https://matrix.to/#/#openvoiceos:matrix.org';;
    en-us:closed) printf '%s' 'No interactive terminal is available. Run the check command in a terminal when you are ready.';;
    en-us:unsafeConfig) printf '%s' 'The setup folder contains an unexpected file or link. Move it aside, then try again. Your settings were not replaced.';;
    en-us:locked) printf '%s' 'A setup is running, or an interrupted attempt left a lock. First make sure no setup is running. Then remove this lock folder and try again:';;
    en-us:runtimeBackup) printf '%s' 'Previous installer tools saved to:';;
    fr-fr:bits) printf '%s' 'OVOS nécessite un système 64 bits. Aucune modification n’a été faite.';;
    fr-fr:invalid) printf '%s' 'Ce code est incorrect ou incomplet. Copiez une nouvelle commande depuis le guide.';;
    fr-fr:expired) printf '%s' 'Ce code a expiré au bout d’une heure. Générez-en un nouveau dans le guide.';;
    fr-fr:future) printf '%s' 'Ce code est daté dans le futur. Vérifiez l’horloge, puis générez un nouveau code.';;
    fr-fr:clock) printf '%s' 'L’horloge du système est incorrecte ou indisponible. Corrigez-la avant de continuer.';;
    fr-fr:regular) printf '%s' 'Lancez cette commande avec votre compte habituel, sans sudo.';;
    fr-fr:mac) printf '%s' 'Cette configuration est destinée à un Mac. Ouvrez Terminal sur ce Mac.';;
    fr-fr:linux) printf '%s' 'Lancez ceci sur votre appareil Linux. Sous Windows, ouvrez Ubuntu dans WSL2.';;
    fr-fr:dependency) printf '%s' 'Installez cet outil, puis collez à nouveau la commande :';;
    fr-fr:existing) printf '%s' 'Déplacez d’abord ~/ovos-installer. Le dossier existant n’a pas été modifié.';;
    fr-fr:checking) printf '%s' '1/4 · Vérification de votre appareil';;
    fr-fr:download) printf '%s' '2/4 · Téléchargement du programme d’installation';;
    fr-fr:downloadFailed) printf '%s' 'Le téléchargement a échoué. Vérifiez votre connexion, puis copiez une nouvelle commande. Vos réglages n’ont pas été remplacés.';;
    fr-fr:revision) printf '%s' 'La version du programme d’installation n’a pas pu être vérifiée. Vos réglages n’ont pas été remplacés.';;
    fr-fr:backup) printf '%s' 'Vos anciens réglages sont sauvegardés ici :';;
    fr-fr:installing) printf '%s' '3/4 · Installation d’OVOS. Cela peut prendre un moment ; suivez les indications ci-dessous.';;
    fr-fr:installFailed) printf '%s' 'L’installation n’a pas abouti. Consultez l’erreur ci-dessus et /var/log/ovos-installer.log. La sauvegarde est conservée. En cas de doute, demandez conseil à la communauté avant de réessayer.';;
    fr-fr:installReturned) printf '%s' 'L’étape d’installation est terminée. Vérifiez les services et essayez la voix avant de considérer la configuration comme prête.';;
    fr-fr:resume) printf '%s' 'Après un redémarrage, ou pour refaire les vérifications, lancez :';;
    fr-fr:cancelHint) printf '%s' 'Tapez :cancel dans un champ, ou appuyez sur Ctrl+C, pour arrêter. Les champs déjà validés sont conservés pendant les corrections.';;
    fr-fr:cancelled) printf '%s' 'Annulé. L’installation n’a pas commencé et vos anciens réglages sont toujours actifs.';;
    fr-fr:required) printf '%s' 'Ce champ est obligatoire. Réessayez, ou tapez :cancel.';;
    fr-fr:urlError) printf '%s' 'Saisissez une adresse http:// ou https:// complète avec un nom d’hôte, sans espace, mot de passe intégré ni fragment.';;
    fr-fr:haUrl) printf '%s' 'Adresse de Home Assistant : ';;
    fr-fr:haToken) printf '%s' 'Jeton d’accès longue durée Home Assistant : ';;
    fr-fr:llmLocal) printf '%s' 'Connectez votre serveur local existant, compatible avec l’API OpenAI.';;
    fr-fr:llmOnline) printf '%s' 'Connectez le fournisseur en ligne de votre choix, compatible avec l’API OpenAI. Son utilisation peut être payante.';;
    fr-fr:llmUrl) printf '%s' 'Adresse de l’API compatible OpenAI : ';;
    fr-fr:llmModel) printf '%s' 'Nom du modèle : ';;
    fr-fr:llmKey) printf '%s' 'Clé d’API (ou valeur demandée par un serveur local sans clé) : ';;
    fr-fr:bash) printf '%s' 'Installez d’abord Bash 4 ou une version ultérieure.';;
    fr-fr:health) printf '%s' '4/4 · Vérification des services OVOS';;
    fr-fr:servicesOk) printf '%s' 'Les services attendus fonctionnent. Cela ne confirme pas encore que le micro et le haut-parleur marchent.';;
    fr-fr:servicesMissing) printf '%s' 'Certains services ne fonctionnent pas encore. Attendez leur démarrage, ou redémarrez si l’installation le demande, puis refaites la vérification.';;
    fr-fr:servicesUnknown) printf '%s' 'La vérification automatique des services n’est pas disponible ici. L’installation et la voix restent à vérifier.';;
    fr-fr:checkMenu) printf '%s' 'Suite : 1 = essayer le son et le micro, 2 = revérifier les services, Entrée = terminer plus tard : ';;
    fr-fr:audioTest) printf '%s' 'OVOS va prononcer une courte phrase. Écoutez votre appareil.';;
    fr-fr:audioQuestion) printf '%s' 'Avez-vous entendu la phrase ? 1 = oui, 2 = réessayer, Entrée = plus tard : ';;
    fr-fr:audioOk) printf '%s' 'Vous avez confirmé que le haut-parleur fonctionne.';;
    fr-fr:audioFailed) printf '%s' 'Le test sonore n’a pas pu joindre OVOS. Vérifiez les services, le volume et la sortie audio choisie.';;
    fr-fr:voiceIntro) printf '%s' 'Parlez maintenant près du micro. Si vous avez changé le mot d’activation, utilisez le vôtre :';;
    fr-fr:voicePhrase) printf '%s' 'Hey Mycroft, quelle heure est-il ?';;
    fr-fr:voiceQuestion) printf '%s' 'OVOS a-t-il répondu correctement ? 1 = oui, 2 = réessayer, Entrée = plus tard : ';;
    fr-fr:voiceOk) printf '%s' 'Vous avez confirmé la première réponse vocale. Profitez d’OVOS !';;
    fr-fr:incomplete) printf '%s' 'Les vérifications restent à terminer. Reprenez-les avec la commande ci-dessus.';;
    fr-fr:customVoice) printf '%s' 'Vous n’avez pas choisi les compétences incluses. Essayez le mot d’activation puis une commande d’une compétence installée ; la question sur l’heure peut ne pas fonctionner.';;
    fr-fr:hub) printf '%s' 'Cet appareil est un serveur central. Testez le micro et le haut-parleur sur un satellite connecté.';;
    fr-fr:help) printf '%s' 'Besoin d’un coup de main ? Discussion communautaire : https://matrix.to/#/#openvoiceos:matrix.org';;
    fr-fr:closed) printf '%s' 'Aucun terminal interactif n’est disponible. Lancez la commande de vérification dans un terminal lorsque vous serez prêt.';;
    fr-fr:unsafeConfig) printf '%s' 'Le dossier de configuration contient un fichier ou un lien inattendu. Déplacez-le, puis réessayez. Vos réglages n’ont pas été remplacés.';;
    fr-fr:locked) printf '%s' 'Une installation est en cours, ou une tentative interrompue a laissé un verrou. Vérifiez d’abord qu’aucune installation ne tourne. Supprimez ensuite ce dossier de verrouillage, puis réessayez :';;
    fr-fr:runtimeBackup) printf '%s' 'Anciens outils d’installation sauvegardés ici :';;
    de-de:bits) printf '%s' 'OVOS benötigt ein 64-Bit-Betriebssystem. Es wurde nichts geändert.';;
    de-de:invalid) printf '%s' 'Dieser Einrichtungscode ist ungültig oder unvollständig. Kopiere einen neuen Befehl aus dem Assistenten.';;
    de-de:expired) printf '%s' 'Dieser Code ist nach einer Stunde abgelaufen. Erstelle im Assistenten einen neuen.';;
    de-de:future) printf '%s' 'Dieser Code liegt in der Zukunft. Prüfe die Uhrzeit und erstelle einen neuen Code.';;
    de-de:clock) printf '%s' 'Die Systemzeit ist ungültig oder nicht verfügbar. Korrigiere sie, bevor du fortfährst.';;
    de-de:regular) printf '%s' 'Führe diesen Befehl mit deinem normalen Benutzerkonto aus, ohne sudo.';;
    de-de:mac) printf '%s' 'Diese Einrichtung ist für einen Mac. Öffne Terminal auf diesem Mac.';;
    de-de:linux) printf '%s' 'Führe dies auf deinem Linux-Gerät aus. Öffne unter Windows Ubuntu in WSL2.';;
    de-de:dependency) printf '%s' 'Installiere dieses benötigte Programm und füge den Befehl erneut ein:';;
    de-de:existing) printf '%s' 'Verschiebe zuerst ~/ovos-installer. Der vorhandene Ordner wurde nicht verändert.';;
    de-de:checking) printf '%s' '1/4 · Gerät prüfen';;
    de-de:download) printf '%s' '2/4 · Installationsprogramm herunterladen';;
    de-de:downloadFailed) printf '%s' 'Der Download ist fehlgeschlagen. Prüfe die Internetverbindung und kopiere einen neuen Befehl. Deine Einstellungen wurden nicht ersetzt.';;
    de-de:revision) printf '%s' 'Die Version des Installationsprogramms konnte nicht bestätigt werden. Deine Einstellungen wurden nicht ersetzt.';;
    de-de:backup) printf '%s' 'Bisherige Einstellungen gesichert unter:';;
    de-de:installing) printf '%s' '3/4 · OVOS installieren. Das kann etwas dauern; folge den Hinweisen unten.';;
    de-de:installFailed) printf '%s' 'Die Installation wurde nicht abgeschlossen. Prüfe die Meldung oben und /var/log/ovos-installer.log. Deine Sicherung bleibt erhalten. Frage bei Unsicherheit vor einem neuen Versuch in der Community nach.';;
    de-de:installReturned) printf '%s' 'Der Installationsschritt ist beendet. Prüfe die Dienste und teste die Sprachbedienung, bevor du die Einrichtung als abgeschlossen betrachtest.';;
    de-de:resume) printf '%s' 'Nach einem Neustart oder für einen erneuten Test ausführen:';;
    de-de:cancelHint) printf '%s' 'Mit :cancel in einem Feld oder Strg+C kannst du abbrechen. Bereits gültige Eingaben bleiben beim Korrigieren erhalten.';;
    de-de:cancelled) printf '%s' 'Abgebrochen. Die Installation wurde nicht gestartet; deine bisherigen Einstellungen sind weiterhin aktiv.';;
    de-de:required) printf '%s' 'Dieses Feld muss ausgefüllt werden. Versuche es erneut oder gib :cancel ein.';;
    de-de:urlError) printf '%s' 'Gib eine vollständige http://- oder https://-Adresse mit Hostnamen ein, ohne Leerzeichen, eingebettete Passwörter oder Fragmente.';;
    de-de:haUrl) printf '%s' 'Home-Assistant-Adresse: ';;
    de-de:haToken) printf '%s' 'Langlebiges Home-Assistant-Zugriffstoken: ';;
    de-de:llmLocal) printf '%s' 'Verbinde deinen vorhandenen lokalen Modellserver mit OpenAI-kompatibler API.';;
    de-de:llmOnline) printf '%s' 'Verbinde deinen gewählten Online-Anbieter mit OpenAI-kompatibler API. Dabei können Gebühren anfallen.';;
    de-de:llmUrl) printf '%s' 'Adresse der OpenAI-kompatiblen API: ';;
    de-de:llmModel) printf '%s' 'Modellname: ';;
    de-de:llmKey) printf '%s' 'API-Schlüssel (oder der vom lokalen Server verlangte Platzhalter): ';;
    de-de:bash) printf '%s' 'Installiere zuerst Bash 4 oder neuer.';;
    de-de:health) printf '%s' '4/4 · OVOS-Dienste prüfen';;
    de-de:servicesOk) printf '%s' 'Die erwarteten Dienste laufen. Ob Mikrofon und Lautsprecher funktionieren, ist damit noch nicht bestätigt.';;
    de-de:servicesMissing) printf '%s' 'Einige Dienste laufen noch nicht. Warte auf den Start oder starte bei Aufforderung neu und wiederhole die Prüfung.';;
    de-de:servicesUnknown) printf '%s' 'Eine automatische Dienstprüfung ist hier nicht möglich. Installation und Sprachbedienung sind noch nicht bestätigt.';;
    de-de:checkMenu) printf '%s' 'Weiter: 1 = Lautsprecher und Mikrofon testen, 2 = Dienste erneut prüfen, Eingabe = später: ';;
    de-de:audioTest) printf '%s' 'OVOS gibt gleich einen kurzen Testsatz aus. Höre auf dein Gerät.';;
    de-de:audioQuestion) printf '%s' 'Hast du den Satz gehört? 1 = ja, 2 = erneut testen, Eingabe = später: ';;
    de-de:audioOk) printf '%s' 'Du hast den Lautsprechertest bestätigt.';;
    de-de:audioFailed) printf '%s' 'Der Audiotest konnte OVOS nicht erreichen. Prüfe Dienste, Lautstärke und das gewählte Audiogerät.';;
    de-de:voiceIntro) printf '%s' 'Sprich jetzt in der Nähe des Mikrofons. Falls du das Aktivierungswort geändert hast, verwende dein eigenes:';;
    de-de:voicePhrase) printf '%s' 'Hey Mycroft, wie spät ist es?';;
    de-de:voiceQuestion) printf '%s' 'Hat OVOS richtig geantwortet? 1 = ja, 2 = erneut versuchen, Eingabe = später: ';;
    de-de:voiceOk) printf '%s' 'Du hast die erste Sprachantwort bestätigt. Viel Spaß mit OVOS!';;
    de-de:incomplete) printf '%s' 'Die Prüfung ist noch offen. Mit dem obigen Befehl kannst du sie fortsetzen.';;
    de-de:customVoice) printf '%s' 'Du hast keine mitgelieferten Skills gewählt. Teste einen Befehl eines selbst installierten Skills; die Zeitfrage ist möglicherweise nicht verfügbar.';;
    de-de:hub) printf '%s' 'Dies ist eine Zentrale. Prüfe Mikrofon und Lautsprecher an einem verbundenen Sprachsatelliten.';;
    de-de:help) printf '%s' 'Brauchst du Hilfe? Community-Chat: https://matrix.to/#/#openvoiceos:matrix.org';;
    de-de:closed) printf '%s' 'Kein interaktives Terminal verfügbar. Führe den Prüfbefehl später in einem Terminal aus.';;
    de-de:unsafeConfig) printf '%s' 'Im Einrichtungsordner liegt eine unerwartete Datei oder Verknüpfung. Verschiebe sie und versuche es erneut. Deine Einstellungen wurden nicht ersetzt.';;
    de-de:locked) printf '%s' 'Eine Einrichtung läuft noch oder hat nach einem Abbruch eine Sperre hinterlassen. Prüfe zuerst, dass keine Einrichtung mehr läuft. Entferne dann diesen Sperrordner und versuche es erneut:';;
    de-de:runtimeBackup) printf '%s' 'Bisherige Installationstools gesichert unter:';;
    es-es:bits) printf '%s' 'OVOS necesita un sistema operativo de 64 bits. No se ha cambiado nada.';;
    es-es:invalid) printf '%s' 'El código no es válido o está incompleto. Copia un comando nuevo del asistente.';;
    es-es:expired) printf '%s' 'Este código ha caducado tras una hora. Genera uno nuevo en el asistente.';;
    es-es:future) printf '%s' 'El código tiene una fecha futura. Comprueba el reloj y genera otro.';;
    es-es:clock) printf '%s' 'El reloj del sistema no es válido o no está disponible. Corrígelo antes de continuar.';;
    es-es:regular) printf '%s' 'Ejecuta el comando con tu cuenta habitual, sin sudo.';;
    es-es:mac) printf '%s' 'Esta configuración es para un Mac. Abre Terminal en ese Mac.';;
    es-es:linux) printf '%s' 'Ejecuta esto en tu dispositivo Linux. En Windows, abre Ubuntu en WSL2.';;
    es-es:dependency) printf '%s' 'Instala esta herramienta y vuelve a pegar el comando:';;
    es-es:existing) printf '%s' 'Mueve primero ~/ovos-installer a otro lugar. La carpeta existente no se ha modificado.';;
    es-es:checking) printf '%s' '1/4 · Comprobando tu dispositivo';;
    es-es:download) printf '%s' '2/4 · Descargando el instalador';;
    es-es:downloadFailed) printf '%s' 'La descarga ha fallado. Comprueba la conexión y copia un comando nuevo. No se han sustituido tus ajustes.';;
    es-es:revision) printf '%s' 'No se ha podido verificar la versión del instalador. No se han sustituido tus ajustes.';;
    es-es:backup) printf '%s' 'Copia de los ajustes anteriores guardada en:';;
    es-es:installing) printf '%s' '3/4 · Instalando OVOS. Puede tardar un poco; sigue las indicaciones de abajo.';;
    es-es:installFailed) printf '%s' 'La instalación no ha terminado. Consulta el error anterior y /var/log/ovos-installer.log. Conservamos la copia de tus ajustes. Si tienes dudas, pregunta a la comunidad antes de reintentarlo.';;
    es-es:installReturned) printf '%s' 'El paso del instalador ha terminado. Comprueba los servicios y prueba la voz antes de dar la configuración por terminada.';;
    es-es:resume) printf '%s' 'Después de reiniciar, o para volver a comprobarlo, ejecuta:';;
    es-es:cancelHint) printf '%s' 'Escribe :cancel en cualquier campo o pulsa Ctrl+C para cancelar. Las respuestas válidas se conservan mientras corriges las demás.';;
    es-es:cancelled) printf '%s' 'Cancelado. La instalación no ha empezado y tus ajustes anteriores siguen activos.';;
    es-es:required) printf '%s' 'Este campo es obligatorio. Inténtalo de nuevo o escribe :cancel.';;
    es-es:urlError) printf '%s' 'Introduce una dirección http:// o https:// completa, con servidor y sin espacios, contraseñas incrustadas ni fragmentos.';;
    es-es:haUrl) printf '%s' 'Dirección de Home Assistant: ';;
    es-es:haToken) printf '%s' 'Token de acceso de larga duración de Home Assistant: ';;
    es-es:llmLocal) printf '%s' 'Conecta tu servidor local existente compatible con la API de OpenAI.';;
    es-es:llmOnline) printf '%s' 'Conecta el proveedor en línea que hayas elegido, compatible con la API de OpenAI. Puede cobrar por el uso.';;
    es-es:llmUrl) printf '%s' 'Dirección de la API compatible con OpenAI: ';;
    es-es:llmModel) printf '%s' 'Nombre del modelo: ';;
    es-es:llmKey) printf '%s' 'Clave de API (o el valor que exija un servidor local sin clave): ';;
    es-es:bash) printf '%s' 'Instala primero Bash 4 o posterior.';;
    es-es:health) printf '%s' '4/4 · Comprobando los servicios de OVOS';;
    es-es:servicesOk) printf '%s' 'Los servicios esperados están funcionando. Esto aún no confirma que el micrófono y el altavoz funcionen.';;
    es-es:servicesMissing) printf '%s' 'Algunos servicios aún no están funcionando. Espera a que arranquen o reinicia si el instalador lo pidió y vuelve a comprobarlo.';;
    es-es:servicesUnknown) printf '%s' 'Aquí no se pueden comprobar los servicios automáticamente. La instalación y la voz siguen sin verificar.';;
    es-es:checkMenu) printf '%s' 'Siguiente: 1 = probar altavoz y micrófono, 2 = comprobar servicios otra vez, Intro = más tarde: ';;
    es-es:audioTest) printf '%s' 'OVOS va a reproducir una frase breve. Escucha tu dispositivo.';;
    es-es:audioQuestion) printf '%s' '¿La has oído? 1 = sí, 2 = repetir, Intro = más tarde: ';;
    es-es:audioOk) printf '%s' 'Has confirmado que el altavoz funciona.';;
    es-es:audioFailed) printf '%s' 'La prueba de sonido no ha podido conectar con OVOS. Revisa los servicios, el volumen y el dispositivo de audio elegido.';;
    es-es:voiceIntro) printf '%s' 'Habla cerca del micrófono. Si has cambiado la palabra de activación, utiliza la tuya:';;
    es-es:voicePhrase) printf '%s' 'Hey Mycroft, ¿qué hora es?';;
    es-es:voiceQuestion) printf '%s' '¿OVOS ha respondido correctamente? 1 = sí, 2 = repetir, Intro = más tarde: ';;
    es-es:voiceOk) printf '%s' 'Has confirmado la primera respuesta de voz. ¡Disfruta de OVOS!';;
    es-es:incomplete) printf '%s' 'La comprobación queda pendiente. Puedes retomarla con el comando anterior.';;
    es-es:customVoice) printf '%s' 'No has elegido las habilidades incluidas. Prueba un comando de una habilidad instalada por ti; la pregunta sobre la hora puede no estar disponible.';;
    es-es:hub) printf '%s' 'Este dispositivo es un servidor central. Prueba el micrófono y el altavoz en un satélite conectado.';;
    es-es:help) printf '%s' '¿Necesitas ayuda? Chat de la comunidad: https://matrix.to/#/#openvoiceos:matrix.org';;
    es-es:closed) printf '%s' 'No hay un terminal interactivo. Ejecuta el comando de comprobación en un terminal cuando quieras continuar.';;
    es-es:unsafeConfig) printf '%s' 'La carpeta de configuración contiene un archivo o enlace inesperado. Muévelo a otro lugar y vuelve a intentarlo. No se han sustituido tus ajustes.';;
    es-es:locked) printf '%s' 'Hay una instalación en curso o un intento interrumpido ha dejado un bloqueo. Primero comprueba que no haya ninguna instalación en marcha. Después elimina esta carpeta de bloqueo y vuelve a intentarlo:';;
    es-es:runtimeBackup) printf '%s' 'Herramientas del instalador anteriores guardadas en:';;
    it-it:bits) printf '%s' 'OVOS richiede un sistema operativo a 64 bit. Non è stato modificato nulla.';;
    it-it:invalid) printf '%s' 'Il codice non è valido o è incompleto. Copia un nuovo comando dalla procedura guidata.';;
    it-it:expired) printf '%s' 'Questo codice è scaduto dopo un’ora. Creane uno nuovo nella procedura guidata.';;
    it-it:future) printf '%s' 'Il codice ha una data futura. Controlla l’orologio e creane uno nuovo.';;
    it-it:clock) printf '%s' 'L’orologio di sistema non è valido o non è disponibile. Correggilo prima di continuare.';;
    it-it:regular) printf '%s' 'Esegui il comando dal tuo account abituale, senza sudo.';;
    it-it:mac) printf '%s' 'Questa configurazione è per un Mac. Apri Terminale su quel Mac.';;
    it-it:linux) printf '%s' 'Esegui il comando sul dispositivo Linux. Su Windows, apri Ubuntu in WSL2.';;
    it-it:dependency) printf '%s' 'Installa questo strumento, poi incolla di nuovo il comando:';;
    it-it:existing) printf '%s' 'Sposta prima ~/ovos-installer. La cartella esistente non è stata modificata.';;
    it-it:checking) printf '%s' '1/4 · Controllo del dispositivo';;
    it-it:download) printf '%s' '2/4 · Download del programma di installazione';;
    it-it:downloadFailed) printf '%s' 'Download non riuscito. Controlla la connessione e copia un nuovo comando. Le tue impostazioni non sono state sostituite.';;
    it-it:revision) printf '%s' 'Non è stato possibile verificare la versione del programma di installazione. Le tue impostazioni non sono state sostituite.';;
    it-it:backup) printf '%s' 'Copia delle impostazioni precedenti salvata in:';;
    it-it:installing) printf '%s' '3/4 · Installazione di OVOS. Potrebbe volerci un po’; segui le indicazioni qui sotto.';;
    it-it:installFailed) printf '%s' 'L’installazione non è terminata. Controlla l’errore sopra e /var/log/ovos-installer.log. La copia delle impostazioni è conservata. Se hai dubbi, chiedi alla comunità prima di riprovare.';;
    it-it:installReturned) printf '%s' 'La fase di installazione è terminata. Controlla i servizi e prova la voce prima di considerare completa la configurazione.';;
    it-it:resume) printf '%s' 'Dopo un riavvio, o per ripetere il controllo, esegui:';;
    it-it:cancelHint) printf '%s' 'Scrivi :cancel in qualsiasi campo o premi Ctrl+C per annullare. I dati validi restano mentre correggi gli altri.';;
    it-it:cancelled) printf '%s' 'Annullato. L’installazione non è iniziata e le impostazioni precedenti sono ancora attive.';;
    it-it:required) printf '%s' 'Questo campo è obbligatorio. Riprova oppure scrivi :cancel.';;
    it-it:urlError) printf '%s' 'Inserisci un indirizzo http:// o https:// completo di host, senza spazi, password incorporate o frammenti.';;
    it-it:haUrl) printf '%s' 'Indirizzo di Home Assistant: ';;
    it-it:haToken) printf '%s' 'Token di accesso a lunga durata di Home Assistant: ';;
    it-it:llmLocal) printf '%s' 'Collega il tuo server locale esistente, compatibile con l’API OpenAI.';;
    it-it:llmOnline) printf '%s' 'Collega il fornitore online scelto, compatibile con l’API OpenAI. Potrebbero esserci costi di utilizzo.';;
    it-it:llmUrl) printf '%s' 'Indirizzo dell’API compatibile con OpenAI: ';;
    it-it:llmModel) printf '%s' 'Nome del modello: ';;
    it-it:llmKey) printf '%s' 'Chiave API (o il valore richiesto da un server locale senza chiave): ';;
    it-it:bash) printf '%s' 'Installa prima Bash 4 o successivo.';;
    it-it:health) printf '%s' '4/4 · Controllo dei servizi OVOS';;
    it-it:servicesOk) printf '%s' 'I servizi previsti sono in esecuzione. Questo non conferma ancora che microfono e altoparlante funzionino.';;
    it-it:servicesMissing) printf '%s' 'Alcuni servizi non sono ancora attivi. Attendi l’avvio o riavvia se richiesto, poi ripeti il controllo.';;
    it-it:servicesUnknown) printf '%s' 'Qui non è disponibile il controllo automatico dei servizi. Installazione e voce restano da verificare.';;
    it-it:checkMenu) printf '%s' 'Avanti: 1 = prova altoparlante e microfono, 2 = ricontrolla i servizi, Invio = più tardi: ';;
    it-it:audioTest) printf '%s' 'OVOS pronuncerà una breve frase di prova. Ascolta il dispositivo.';;
    it-it:audioQuestion) printf '%s' 'Hai sentito la frase? 1 = sì, 2 = riprova, Invio = più tardi: ';;
    it-it:audioOk) printf '%s' 'Hai confermato che l’altoparlante funziona.';;
    it-it:audioFailed) printf '%s' 'La prova audio non ha raggiunto OVOS. Controlla servizi, volume e dispositivo audio selezionato.';;
    it-it:voiceIntro) printf '%s' 'Ora parla vicino al microfono. Se hai cambiato la parola di attivazione, usa la tua:';;
    it-it:voicePhrase) printf '%s' 'Hey Mycroft, che ore sono?';;
    it-it:voiceQuestion) printf '%s' 'OVOS ha risposto correttamente? 1 = sì, 2 = riprova, Invio = più tardi: ';;
    it-it:voiceOk) printf '%s' 'Hai confermato la prima risposta vocale. Buon divertimento con OVOS!';;
    it-it:incomplete) printf '%s' 'Il controllo non è completo. Puoi riprenderlo con il comando sopra.';;
    it-it:customVoice) printf '%s' 'Non hai scelto le abilità incluse. Prova un comando di un’abilità installata da te; la domanda sull’ora potrebbe non essere disponibile.';;
    it-it:hub) printf '%s' 'Questo dispositivo è un hub. Verifica microfono e altoparlante su un satellite collegato.';;
    it-it:help) printf '%s' 'Serve aiuto? Chat della comunità: https://matrix.to/#/#openvoiceos:matrix.org';;
    it-it:closed) printf '%s' 'Non è disponibile un terminale interattivo. Esegui il comando di verifica in un terminale quando sei pronto.';;
    it-it:unsafeConfig) printf '%s' 'La cartella di configurazione contiene un file o collegamento inatteso. Spostalo altrove e riprova. Le tue impostazioni non sono state sostituite.';;
    it-it:locked) printf '%s' 'È in corso un’installazione, oppure un tentativo interrotto ha lasciato un blocco. Prima verifica che non ci siano installazioni in corso. Poi rimuovi questa cartella di blocco e riprova:';;
    it-it:runtimeBackup) printf '%s' 'Strumenti di installazione precedenti salvati in:';;
    nl-nl:bits) printf '%s' 'OVOS heeft een 64-bits besturingssysteem nodig. Er is niets gewijzigd.';;
    nl-nl:invalid) printf '%s' 'Deze instelcode is ongeldig of onvolledig. Kopieer een nieuw commando uit de wizard.';;
    nl-nl:expired) printf '%s' 'Deze code is na een uur verlopen. Maak een nieuwe code in de wizard.';;
    nl-nl:future) printf '%s' 'Deze code ligt in de toekomst. Controleer de klok en maak een nieuwe code.';;
    nl-nl:clock) printf '%s' 'De systeemklok klopt niet of is niet beschikbaar. Herstel de klok voordat je verdergaat.';;
    nl-nl:regular) printf '%s' 'Voer dit commando uit met je gewone gebruikersaccount, zonder sudo.';;
    nl-nl:mac) printf '%s' 'Deze instelling is voor een Mac. Open Terminal op die Mac.';;
    nl-nl:linux) printf '%s' 'Voer dit uit op je Linux-apparaat. Open op Windows Ubuntu in WSL2.';;
    nl-nl:dependency) printf '%s' 'Installeer dit programma en plak het commando opnieuw:';;
    nl-nl:existing) printf '%s' 'Verplaats eerst ~/ovos-installer. De bestaande map is niet gewijzigd.';;
    nl-nl:checking) printf '%s' '1/4 · Je apparaat controleren';;
    nl-nl:download) printf '%s' '2/4 · Het installatieprogramma downloaden';;
    nl-nl:downloadFailed) printf '%s' 'Downloaden is mislukt. Controleer je internetverbinding en kopieer een nieuw commando. Je instellingen zijn niet vervangen.';;
    nl-nl:revision) printf '%s' 'De versie van het installatieprogramma kon niet worden gecontroleerd. Je instellingen zijn niet vervangen.';;
    nl-nl:backup) printf '%s' 'Eerdere instellingen opgeslagen in:';;
    nl-nl:installing) printf '%s' '3/4 · OVOS installeren. Dit kan even duren; volg de aanwijzingen hieronder.';;
    nl-nl:installFailed) printf '%s' 'De installatie is niet voltooid. Bekijk de fout hierboven en /var/log/ovos-installer.log. Je reservekopie blijft bewaard. Vraag bij twijfel de gemeenschap om hulp voordat je opnieuw probeert.';;
    nl-nl:installReturned) printf '%s' 'De installatiestap is afgelopen. Controleer de diensten en test de spraak voordat je de installatie als voltooid beschouwt.';;
    nl-nl:resume) printf '%s' 'Voer na een herstart, of om opnieuw te controleren, dit uit:';;
    nl-nl:cancelHint) printf '%s' 'Typ :cancel in een veld of druk op Ctrl+C om te stoppen. Geldige antwoorden blijven bewaard terwijl je andere velden corrigeert.';;
    nl-nl:cancelled) printf '%s' 'Geannuleerd. De installatie is niet gestart en je eerdere instellingen zijn nog actief.';;
    nl-nl:required) printf '%s' 'Dit veld is verplicht. Probeer opnieuw of typ :cancel.';;
    nl-nl:urlError) printf '%s' 'Vul een volledig http://- of https://-adres met host in, zonder spaties, opgenomen wachtwoorden of fragmenten.';;
    nl-nl:haUrl) printf '%s' 'Home Assistant-adres: ';;
    nl-nl:haToken) printf '%s' 'Home Assistant-toegangstoken met lange geldigheidsduur: ';;
    nl-nl:llmLocal) printf '%s' 'Verbind je bestaande lokale modelserver met een OpenAI-compatibele API.';;
    nl-nl:llmOnline) printf '%s' 'Verbind je gekozen online aanbieder met een OpenAI-compatibele API. Hiervoor kunnen kosten gelden.';;
    nl-nl:llmUrl) printf '%s' 'Adres van de OpenAI-compatibele API: ';;
    nl-nl:llmModel) printf '%s' 'Modelnaam: ';;
    nl-nl:llmKey) printf '%s' 'API-sleutel (of de waarde die een lokale server zonder sleutel verlangt): ';;
    nl-nl:bash) printf '%s' 'Installeer eerst Bash 4 of nieuwer.';;
    nl-nl:health) printf '%s' '4/4 · OVOS-diensten controleren';;
    nl-nl:servicesOk) printf '%s' 'De verwachte diensten draaien. Dat bevestigt nog niet dat je microfoon en luidspreker werken.';;
    nl-nl:servicesMissing) printf '%s' 'Sommige diensten draaien nog niet. Wacht op het opstarten of herstart als dat werd gevraagd en controleer opnieuw.';;
    nl-nl:servicesUnknown) printf '%s' 'Automatisch controleren is hier niet mogelijk. De installatie en spraak zijn nog niet geverifieerd.';;
    nl-nl:checkMenu) printf '%s' 'Verder: 1 = luidspreker en microfoon testen, 2 = diensten opnieuw controleren, Enter = later: ';;
    nl-nl:audioTest) printf '%s' 'OVOS gaat een korte testzin uitspreken. Luister naar je apparaat.';;
    nl-nl:audioQuestion) printf '%s' 'Heb je de zin gehoord? 1 = ja, 2 = opnieuw proberen, Enter = later: ';;
    nl-nl:audioOk) printf '%s' 'Je hebt bevestigd dat de luidspreker werkt.';;
    nl-nl:audioFailed) printf '%s' 'De geluidstest kon OVOS niet bereiken. Controleer diensten, volume en het gekozen audioapparaat.';;
    nl-nl:voiceIntro) printf '%s' 'Spreek nu bij de microfoon. Gebruik je eigen wekwoord als je dat hebt aangepast:';;
    nl-nl:voicePhrase) printf '%s' 'Hey Mycroft, hoe laat is het?';;
    nl-nl:voiceQuestion) printf '%s' 'Gaf OVOS het juiste antwoord? 1 = ja, 2 = opnieuw proberen, Enter = later: ';;
    nl-nl:voiceOk) printf '%s' 'Je hebt het eerste gesproken antwoord bevestigd. Veel plezier met OVOS!';;
    nl-nl:incomplete) printf '%s' 'De controle is nog niet afgerond. Je kunt doorgaan met het commando hierboven.';;
    nl-nl:customVoice) printf '%s' 'Je hebt geen meegeleverde vaardigheden gekozen. Probeer een commando van een zelf geïnstalleerde vaardigheid; de tijdsvraag werkt mogelijk niet.';;
    nl-nl:hub) printf '%s' 'Dit apparaat is een hub. Test microfoon en luidspreker op een verbonden satelliet.';;
    nl-nl:help) printf '%s' 'Hulp nodig? Communitychat: https://matrix.to/#/#openvoiceos:matrix.org';;
    nl-nl:closed) printf '%s' 'Er is geen interactieve terminal. Voer het controlecommando later in een terminal uit.';;
    nl-nl:unsafeConfig) printf '%s' 'De instelmap bevat een onverwacht bestand of een onverwachte koppeling. Verplaats dit naar een andere plek en probeer het opnieuw. Je instellingen zijn niet vervangen.';;
    nl-nl:locked) printf '%s' 'Er loopt een installatie, of een onderbroken poging heeft een vergrendeling achtergelaten. Controleer eerst of er geen installatie meer draait. Verwijder daarna deze vergrendelingsmap en probeer het opnieuw:';;
    nl-nl:runtimeBackup) printf '%s' 'Vorige installatiehulpmiddelen bewaard in:';;
    pt-pt:bits) printf '%s' 'O OVOS precisa de um sistema operativo de 64 bits. Não foi feita nenhuma alteração.';;
    pt-pt:invalid) printf '%s' 'O código é inválido ou está incompleto. Copia um novo comando do assistente.';;
    pt-pt:expired) printf '%s' 'Este código expirou ao fim de uma hora. Gera outro no assistente.';;
    pt-pt:future) printf '%s' 'Este código tem uma data futura. Confirma o relógio e gera outro.';;
    pt-pt:clock) printf '%s' 'O relógio do sistema é inválido ou não está disponível. Corrige-o antes de continuar.';;
    pt-pt:regular) printf '%s' 'Executa este comando com a tua conta habitual, sem sudo.';;
    pt-pt:mac) printf '%s' 'Esta configuração é para um Mac. Abre o Terminal nesse Mac.';;
    pt-pt:linux) printf '%s' 'Executa isto no dispositivo Linux. No Windows, abre o Ubuntu no WSL2.';;
    pt-pt:dependency) printf '%s' 'Instala esta ferramenta e volta a colar o comando:';;
    pt-pt:existing) printf '%s' 'Move primeiro ~/ovos-installer para outro local. A pasta existente não foi alterada.';;
    pt-pt:checking) printf '%s' '1/4 · A verificar o dispositivo';;
    pt-pt:download) printf '%s' '2/4 · A descarregar o instalador';;
    pt-pt:downloadFailed) printf '%s' 'A transferência falhou. Verifica a ligação à internet e copia um novo comando. As tuas definições não foram substituídas.';;
    pt-pt:revision) printf '%s' 'Não foi possível verificar a versão do instalador. As tuas definições não foram substituídas.';;
    pt-pt:backup) printf '%s' 'Cópia das definições anteriores guardada em:';;
    pt-pt:installing) printf '%s' '3/4 · A instalar o OVOS. Pode demorar um pouco; segue as indicações abaixo.';;
    pt-pt:installFailed) printf '%s' 'A instalação não foi concluída. Consulta o erro acima e /var/log/ovos-installer.log. A cópia das definições foi mantida. Em caso de dúvida, pede ajuda à comunidade antes de tentar de novo.';;
    pt-pt:installReturned) printf '%s' 'A etapa do instalador terminou. Verifica os serviços e testa a voz antes de dares a configuração por concluída.';;
    pt-pt:resume) printf '%s' 'Depois de reiniciar, ou para voltar a verificar, executa:';;
    pt-pt:cancelHint) printf '%s' 'Escreve :cancel num campo ou prime Ctrl+C para cancelar. As respostas válidas mantêm-se enquanto corriges as restantes.';;
    pt-pt:cancelled) printf '%s' 'Cancelado. A instalação não começou e as definições anteriores continuam ativas.';;
    pt-pt:required) printf '%s' 'Este campo é obrigatório. Tenta novamente ou escreve :cancel.';;
    pt-pt:urlError) printf '%s' 'Introduz um endereço http:// ou https:// completo, com servidor, sem espaços, palavras-passe incorporadas ou fragmentos.';;
    pt-pt:haUrl) printf '%s' 'Endereço do Home Assistant: ';;
    pt-pt:haToken) printf '%s' 'Token de acesso de longa duração do Home Assistant: ';;
    pt-pt:llmLocal) printf '%s' 'Liga o teu servidor local existente, compatível com a API OpenAI.';;
    pt-pt:llmOnline) printf '%s' 'Liga o fornecedor online escolhido, compatível com a API OpenAI. A utilização pode ter custos.';;
    pt-pt:llmUrl) printf '%s' 'Endereço da API compatível com OpenAI: ';;
    pt-pt:llmModel) printf '%s' 'Nome do modelo: ';;
    pt-pt:llmKey) printf '%s' 'Chave de API (ou o valor exigido por um servidor local sem chave): ';;
    pt-pt:bash) printf '%s' 'Instala primeiro o Bash 4 ou mais recente.';;
    pt-pt:health) printf '%s' '4/4 · A verificar os serviços do OVOS';;
    pt-pt:servicesOk) printf '%s' 'Os serviços esperados estão a funcionar. Isto ainda não confirma o funcionamento do microfone e do altifalante.';;
    pt-pt:servicesMissing) printf '%s' 'Alguns serviços ainda não estão a funcionar. Aguarda pelo arranque ou reinicia, se solicitado, e volta a verificar.';;
    pt-pt:servicesUnknown) printf '%s' 'A verificação automática dos serviços não está disponível aqui. A instalação e a voz continuam por verificar.';;
    pt-pt:checkMenu) printf '%s' 'Seguinte: 1 = testar altifalante e microfone, 2 = voltar a verificar serviços, Enter = mais tarde: ';;
    pt-pt:audioTest) printf '%s' 'O OVOS vai dizer uma frase curta. Ouve o dispositivo.';;
    pt-pt:audioQuestion) printf '%s' 'Ouviste a frase? 1 = sim, 2 = repetir, Enter = mais tarde: ';;
    pt-pt:audioOk) printf '%s' 'Confirmaste que o altifalante funciona.';;
    pt-pt:audioFailed) printf '%s' 'O teste de som não conseguiu contactar o OVOS. Verifica os serviços, o volume e o dispositivo de áudio escolhido.';;
    pt-pt:voiceIntro) printf '%s' 'Fala agora perto do microfone. Se alteraste a palavra de ativação, usa a tua:';;
    pt-pt:voicePhrase) printf '%s' 'Hey Mycroft, que horas são?';;
    pt-pt:voiceQuestion) printf '%s' 'O OVOS respondeu corretamente? 1 = sim, 2 = repetir, Enter = mais tarde: ';;
    pt-pt:voiceOk) printf '%s' 'Confirmaste a primeira resposta por voz. Diverte-te com o OVOS!';;
    pt-pt:incomplete) printf '%s' 'A verificação está por terminar. Podes retomá-la com o comando acima.';;
    pt-pt:customVoice) printf '%s' 'Não escolheste as competências incluídas. Testa um comando de uma competência que instalaste; a pergunta sobre as horas pode não estar disponível.';;
    pt-pt:hub) printf '%s' 'Este dispositivo é um servidor central. Testa o microfone e o altifalante num satélite ligado.';;
    pt-pt:help) printf '%s' 'Precisas de ajuda? Conversa da comunidade: https://matrix.to/#/#openvoiceos:matrix.org';;
    pt-pt:closed) printf '%s' 'Não há um terminal interativo disponível. Executa o comando de verificação num terminal quando quiseres continuar.';;
    pt-pt:unsafeConfig) printf '%s' 'A pasta de configuração contém um ficheiro ou uma ligação inesperados. Move-os para outro local e tenta novamente. As tuas definições não foram substituídas.';;
    pt-pt:locked) printf '%s' 'Está a decorrer uma instalação, ou uma tentativa interrompida deixou um bloqueio. Primeiro, confirma que não está a decorrer nenhuma instalação. Depois remove esta pasta de bloqueio e tenta novamente:';;
    pt-pt:runtimeBackup) printf '%s' 'Ferramentas de instalação anteriores guardadas em:';;
    ca-es:bits) printf '%s' 'OVOS necessita un sistema operatiu de 64 bits. No s’ha canviat res.';;
    ca-es:invalid) printf '%s' 'El codi no és vàlid o és incomplet. Copia una ordre nova de l’assistent.';;
    ca-es:expired) printf '%s' 'Aquest codi ha caducat al cap d’una hora. Genera’n un de nou a l’assistent.';;
    ca-es:future) printf '%s' 'El codi té una data futura. Comprova el rellotge i genera’n un de nou.';;
    ca-es:clock) printf '%s' 'El rellotge del sistema no és vàlid o no està disponible. Corregeix-lo abans de continuar.';;
    ca-es:regular) printf '%s' 'Executa aquesta ordre amb el teu compte habitual, sense sudo.';;
    ca-es:mac) printf '%s' 'Aquesta configuració és per a un Mac. Obre Terminal en aquell Mac.';;
    ca-es:linux) printf '%s' 'Executa això al dispositiu Linux. Al Windows, obre Ubuntu al WSL2.';;
    ca-es:dependency) printf '%s' 'Instal·la aquesta eina i torna a enganxar l’ordre:';;
    ca-es:existing) printf '%s' 'Mou primer ~/ovos-installer a un altre lloc. La carpeta existent no s’ha modificat.';;
    ca-es:checking) printf '%s' '1/4 · Comprovant el dispositiu';;
    ca-es:download) printf '%s' '2/4 · Baixant l’instal·lador';;
    ca-es:downloadFailed) printf '%s' 'La baixada ha fallat. Comprova la connexió i copia una ordre nova. Els ajustos no s’han substituït.';;
    ca-es:revision) printf '%s' 'No s’ha pogut verificar la versió de l’instal·lador. Els ajustos no s’han substituït.';;
    ca-es:backup) printf '%s' 'Còpia dels ajustos anteriors desada a:';;
    ca-es:installing) printf '%s' '3/4 · Instal·lant OVOS. Pot trigar una estona; segueix les indicacions de sota.';;
    ca-es:installFailed) printf '%s' 'La instal·lació no ha acabat. Consulta l’error de sobre i /var/log/ovos-installer.log. La còpia dels ajustos es conserva. Si tens dubtes, pregunta a la comunitat abans de tornar-ho a provar.';;
    ca-es:installReturned) printf '%s' 'El pas de l’instal·lador ha acabat. Comprova els serveis i prova la veu abans de donar la configuració per acabada.';;
    ca-es:resume) printf '%s' 'Després de reiniciar, o per tornar a comprovar-ho, executa:';;
    ca-es:cancelHint) printf '%s' 'Escriu :cancel en qualsevol camp o prem Ctrl+C per cancel·lar. Les dades vàlides es conserven mentre corregeixes la resta.';;
    ca-es:cancelled) printf '%s' 'Cancel·lat. La instal·lació no ha començat i els ajustos anteriors continuen actius.';;
    ca-es:required) printf '%s' 'Aquest camp és obligatori. Torna-ho a provar o escriu :cancel.';;
    ca-es:urlError) printf '%s' 'Introdueix una adreça http:// o https:// completa, amb servidor, sense espais, contrasenyes incrustades ni fragments.';;
    ca-es:haUrl) printf '%s' 'Adreça de Home Assistant: ';;
    ca-es:haToken) printf '%s' 'Testimoni d’accés de llarga durada de Home Assistant: ';;
    ca-es:llmLocal) printf '%s' 'Connecta el teu servidor local existent, compatible amb l’API d’OpenAI.';;
    ca-es:llmOnline) printf '%s' 'Connecta el proveïdor en línia escollit, compatible amb l’API d’OpenAI. L’ús pot tenir un cost.';;
    ca-es:llmUrl) printf '%s' 'Adreça de l’API compatible amb OpenAI: ';;
    ca-es:llmModel) printf '%s' 'Nom del model: ';;
    ca-es:llmKey) printf '%s' 'Clau d’API (o el valor que demani un servidor local sense clau): ';;
    ca-es:bash) printf '%s' 'Instal·la primer Bash 4 o posterior.';;
    ca-es:health) printf '%s' '4/4 · Comprovant els serveis d’OVOS';;
    ca-es:servicesOk) printf '%s' 'Els serveis esperats funcionen. Això encara no confirma que el micròfon i l’altaveu funcionin.';;
    ca-es:servicesMissing) printf '%s' 'Alguns serveis encara no funcionen. Espera que s’iniciïn o reinicia si t’ho han demanat i torna a comprovar-ho.';;
    ca-es:servicesUnknown) printf '%s' 'Aquí no es poden comprovar els serveis automàticament. La instal·lació i la veu encara no estan verificades.';;
    ca-es:checkMenu) printf '%s' 'Següent: 1 = provar altaveu i micròfon, 2 = comprovar serveis de nou, Retorn = més tard: ';;
    ca-es:audioTest) printf '%s' 'OVOS dirà una frase breu. Escolta el dispositiu.';;
    ca-es:audioQuestion) printf '%s' 'L’has sentida? 1 = sí, 2 = repetir, Retorn = més tard: ';;
    ca-es:audioOk) printf '%s' 'Has confirmat que l’altaveu funciona.';;
    ca-es:audioFailed) printf '%s' 'La prova de so no ha pogut contactar amb OVOS. Revisa els serveis, el volum i el dispositiu d’àudio triat.';;
    ca-es:voiceIntro) printf '%s' 'Parla ara a prop del micròfon. Si has canviat la paraula d’activació, fes servir la teva:';;
    ca-es:voicePhrase) printf '%s' 'Hey Mycroft, quina hora és?';;
    ca-es:voiceQuestion) printf '%s' 'OVOS ha respost correctament? 1 = sí, 2 = repetir, Retorn = més tard: ';;
    ca-es:voiceOk) printf '%s' 'Has confirmat la primera resposta de veu. Gaudeix d’OVOS!';;
    ca-es:incomplete) printf '%s' 'La comprovació queda pendent. Pots reprendre-la amb l’ordre de sobre.';;
    ca-es:customVoice) printf '%s' 'No has triat les habilitats incloses. Prova una ordre d’una habilitat que hagis instal·lat; la pregunta sobre l’hora pot no estar disponible.';;
    ca-es:hub) printf '%s' 'Aquest dispositiu és un servidor central. Prova el micròfon i l’altaveu en un satèl·lit connectat.';;
    ca-es:help) printf '%s' 'Et cal ajuda? Xat de la comunitat: https://matrix.to/#/#openvoiceos:matrix.org';;
    ca-es:closed) printf '%s' 'No hi ha cap terminal interactiu disponible. Executa l’ordre de comprovació en un terminal quan vulguis continuar.';;
    ca-es:unsafeConfig) printf '%s' 'La carpeta de configuració conté un fitxer o un enllaç inesperat. Mou-lo a un altre lloc i torna-ho a provar. Els ajustos no s’han substituït.';;
    ca-es:locked) printf '%s' 'Hi ha una instal·lació en curs, o un intent interromput ha deixat un bloqueig. Primer comprova que no hi hagi cap instal·lació en marxa. Després elimina aquesta carpeta de bloqueig i torna-ho a provar:';;
    ca-es:runtimeBackup) printf '%s' 'Eines d’instal·lació anteriors desades a:';;
    eu-es:bits) printf '%s' 'OVOSek 64 biteko sistema eragilea behar du. Ez da ezer aldatu.';;
    eu-es:invalid) printf '%s' 'Konfigurazio-kodea ez da baliozkoa edo osatu gabe dago. Kopiatu beste komando bat morroitik.';;
    eu-es:expired) printf '%s' 'Kodea ordubete igarota iraungi da. Sortu beste bat morroian.';;
    eu-es:future) printf '%s' 'Kodearen data etorkizunekoa da. Egiaztatu erlojua eta sortu beste kode bat.';;
    eu-es:clock) printf '%s' 'Sistemaren erlojua ez da zuzena edo ezin da irakurri. Zuzendu jarraitu aurretik.';;
    eu-es:regular) printf '%s' 'Exekutatu komando hau zure ohiko erabiltzaile-kontuarekin, sudo gabe.';;
    eu-es:mac) printf '%s' 'Konfigurazio hau Mac baterako da. Ireki Terminal Mac horretan.';;
    eu-es:linux) printf '%s' 'Exekutatu Linux gailuan. Windowsen, ireki Ubuntu WSL2n.';;
    eu-es:dependency) printf '%s' 'Instalatu tresna hau eta itsatsi berriro komandoa:';;
    eu-es:existing) printf '%s' 'Mugitu lehenik ~/ovos-installer beste toki batera. Dagoen karpeta ez da aldatu.';;
    eu-es:checking) printf '%s' '1/4 · Gailua egiaztatzen';;
    eu-es:download) printf '%s' '2/4 · Instalatzailea deskargatzen';;
    eu-es:downloadFailed) printf '%s' 'Deskargak huts egin du. Egiaztatu konexioa eta kopiatu komando berri bat. Ezarpenak ez dira ordeztu.';;
    eu-es:revision) printf '%s' 'Ezin izan da instalatzailearen bertsioa egiaztatu. Ezarpenak ez dira ordeztu.';;
    eu-es:backup) printf '%s' 'Aurreko ezarpenen kopia hemen gorde da:';;
    eu-es:installing) printf '%s' '3/4 · OVOS instalatzen. Baliteke denbora behar izatea; jarraitu beheko argibideei.';;
    eu-es:installFailed) printf '%s' 'Instalazioa ez da amaitu. Begiratu goiko errorea eta /var/log/ovos-installer.log. Babeskopia gordeta dago. Zalantzarik baduzu, galdetu komunitateari berriro saiatu aurretik.';;
    eu-es:installReturned) printf '%s' 'Instalatzailearen urratsa amaitu da. Egiaztatu zerbitzuak eta probatu ahotsa konfigurazioa amaitutzat eman aurretik.';;
    eu-es:resume) printf '%s' 'Berrabiarazi ondoren, edo berriro egiaztatzeko, exekutatu:';;
    eu-es:cancelHint) printf '%s' 'Idatzi :cancel edozein eremutan edo sakatu Ctrl+C gelditzeko. Baliozko erantzunak gordetzen dira gainerakoak zuzentzen dituzun bitartean.';;
    eu-es:cancelled) printf '%s' 'Bertan behera utzi da. Instalazioa ez da hasi eta aurreko ezarpenek aktibo jarraitzen dute.';;
    eu-es:required) printf '%s' 'Eremu hau bete behar da. Saiatu berriro edo idatzi :cancel.';;
    eu-es:urlError) printf '%s' 'Sartu http:// edo https:// helbide oso bat ostalariarekin, zuriunerik, txertatutako pasahitzik edo zatirik gabe.';;
    eu-es:haUrl) printf '%s' 'Home Assistanten helbidea: ';;
    eu-es:haToken) printf '%s' 'Home Assistanten iraupen luzeko sarbide-tokena: ';;
    eu-es:llmLocal) printf '%s' 'Konektatu lehendik duzun tokiko modelo-zerbitzaria, OpenAI APIarekin bateragarria.';;
    eu-es:llmOnline) printf '%s' 'Konektatu aukeratutako lineako hornitzailea, OpenAI APIarekin bateragarria. Erabilera ordaindu beharra egon daiteke.';;
    eu-es:llmUrl) printf '%s' 'OpenAIrekin bateragarria den APIaren helbidea: ';;
    eu-es:llmModel) printf '%s' 'Modeloaren izena: ';;
    eu-es:llmKey) printf '%s' 'API gakoa (edo gakorik gabeko tokiko zerbitzariak eskatutako balioa): ';;
    eu-es:bash) printf '%s' 'Instalatu lehenik Bash 4 edo berriagoa.';;
    eu-es:health) printf '%s' '4/4 · OVOSen zerbitzuak egiaztatzen';;
    eu-es:servicesOk) printf '%s' 'Espero diren zerbitzuak martxan daude. Horrek ez du oraindik mikrofonoa eta bozgorailua dabiltzanik baieztatzen.';;
    eu-es:servicesMissing) printf '%s' 'Zerbitzu batzuk oraindik ez daude martxan. Itxaron abiarazi arte, edo berrabiarazi eskatu bazaizu, eta egiaztatu berriro.';;
    eu-es:servicesUnknown) printf '%s' 'Hemen ezin dira zerbitzuak automatikoki egiaztatu. Instalazioa eta ahotsa egiaztatu gabe daude.';;
    eu-es:checkMenu) printf '%s' 'Hurrengoa: 1 = bozgorailua eta mikrofonoa probatu, 2 = zerbitzuak berriro egiaztatu, Sartu = geroago: ';;
    eu-es:audioTest) printf '%s' 'OVOSek probako esaldi labur bat esango du. Entzun gailua.';;
    eu-es:audioQuestion) printf '%s' 'Entzun duzu? 1 = bai, 2 = berriro probatu, Sartu = geroago: ';;
    eu-es:audioOk) printf '%s' 'Bozgorailua badabilela baieztatu duzu.';;
    eu-es:audioFailed) printf '%s' 'Soinu-probak ezin izan du OVOSekin konektatu. Egiaztatu zerbitzuak, bolumena eta aukeratutako audio-gailua.';;
    eu-es:voiceIntro) printf '%s' 'Hitz egin mikrofonotik gertu. Esnatze-hitza aldatu baduzu, erabili zurea:';;
    eu-es:voicePhrase) printf '%s' 'Hey Mycroft, zer ordu da?';;
    eu-es:voiceQuestion) printf '%s' 'OVOSek zuzen erantzun du? 1 = bai, 2 = berriro probatu, Sartu = geroago: ';;
    eu-es:voiceOk) printf '%s' 'Lehen ahots-erantzuna baieztatu duzu. Gozatu OVOSekin!';;
    eu-es:incomplete) printf '%s' 'Egiaztapena amaitu gabe dago. Goiko komandoarekin jarrai dezakezu.';;
    eu-es:customVoice) printf '%s' 'Ez dituzu barneko trebetasunak aukeratu. Probatu zuk instalatutako baten komandoa; ordua galdetzeko aukera ez dago agian erabilgarri.';;
    eu-es:hub) printf '%s' 'Gailu hau zerbitzari nagusia da. Probatu mikrofonoa eta bozgorailua konektatutako satelite batean.';;
    eu-es:help) printf '%s' 'Laguntza behar duzu? Komunitatearen txata: https://matrix.to/#/#openvoiceos:matrix.org';;
    eu-es:closed) printf '%s' 'Ez dago terminal interaktiborik. Prest zaudenean, exekutatu egiaztapen-komandoa terminal batean.';;
    eu-es:unsafeConfig) printf '%s' 'Konfigurazio-karpetan espero ez zen fitxategi edo esteka bat dago. Mugitu beste toki batera eta saiatu berriro. Ezarpenak ez dira ordeztu.';;
    eu-es:locked) printf '%s' 'Instalazio bat martxan dago, edo etendako saiakera batek blokeoa utzi du. Lehenik, ziurtatu ez dagoela instalaziorik martxan. Ondoren, ezabatu blokeo-karpeta hau eta saiatu berriro:';;
    eu-es:runtimeBackup) printf '%s' 'Aurreko instalazio-tresnak hemen gorde dira:';;
    gl-es:bits) printf '%s' 'OVOS precisa un sistema operativo de 64 bits. Non se cambiou nada.';;
    gl-es:invalid) printf '%s' 'O código non é válido ou está incompleto. Copia un comando novo do asistente.';;
    gl-es:expired) printf '%s' 'Este código caducou ao cabo dunha hora. Xera outro no asistente.';;
    gl-es:future) printf '%s' 'O código ten unha data futura. Comproba o reloxo e xera outro.';;
    gl-es:clock) printf '%s' 'O reloxo do sistema non é válido ou non está dispoñible. Corríxeo antes de continuar.';;
    gl-es:regular) printf '%s' 'Executa este comando coa túa conta habitual, sen sudo.';;
    gl-es:mac) printf '%s' 'Esta configuración é para un Mac. Abre Terminal nese Mac.';;
    gl-es:linux) printf '%s' 'Executa isto no dispositivo Linux. En Windows, abre Ubuntu en WSL2.';;
    gl-es:dependency) printf '%s' 'Instala esta ferramenta e volve pegar o comando:';;
    gl-es:existing) printf '%s' 'Move primeiro ~/ovos-installer a outro lugar. O cartafol existente non se modificou.';;
    gl-es:checking) printf '%s' '1/4 · Comprobando o dispositivo';;
    gl-es:download) printf '%s' '2/4 · Descargando o instalador';;
    gl-es:downloadFailed) printf '%s' 'Fallou a descarga. Comproba a conexión e copia un comando novo. Non se substituíron os axustes.';;
    gl-es:revision) printf '%s' 'Non se puido verificar a versión do instalador. Non se substituíron os axustes.';;
    gl-es:backup) printf '%s' 'Copia dos axustes anteriores gardada en:';;
    gl-es:installing) printf '%s' '3/4 · Instalando OVOS. Pode levar un anaco; segue as indicacións de abaixo.';;
    gl-es:installFailed) printf '%s' 'A instalación non rematou. Consulta o erro anterior e /var/log/ovos-installer.log. Consérvase a copia dos axustes. Se tes dúbidas, pregunta á comunidade antes de tentalo outra vez.';;
    gl-es:installReturned) printf '%s' 'O paso do instalador rematou. Comproba os servizos e proba a voz antes de dar a configuración por rematada.';;
    gl-es:resume) printf '%s' 'Despois de reiniciar, ou para volver comprobalo, executa:';;
    gl-es:cancelHint) printf '%s' 'Escribe :cancel en calquera campo ou preme Ctrl+C para cancelar. Os datos válidos consérvanse mentres corrixes os demais.';;
    gl-es:cancelled) printf '%s' 'Cancelado. A instalación non comezou e os axustes anteriores seguen activos.';;
    gl-es:required) printf '%s' 'Este campo é obrigatorio. Téntao de novo ou escribe :cancel.';;
    gl-es:urlError) printf '%s' 'Introduce un enderezo http:// ou https:// completo, con servidor, sen espazos, contrasinais incrustados nin fragmentos.';;
    gl-es:haUrl) printf '%s' 'Enderezo de Home Assistant: ';;
    gl-es:haToken) printf '%s' 'Token de acceso de longa duración de Home Assistant: ';;
    gl-es:llmLocal) printf '%s' 'Conecta o teu servidor local existente, compatible coa API de OpenAI.';;
    gl-es:llmOnline) printf '%s' 'Conecta o provedor en liña escollido, compatible coa API de OpenAI. O uso pode ter custos.';;
    gl-es:llmUrl) printf '%s' 'Enderezo da API compatible con OpenAI: ';;
    gl-es:llmModel) printf '%s' 'Nome do modelo: ';;
    gl-es:llmKey) printf '%s' 'Chave da API (ou o valor que pida un servidor local sen chave): ';;
    gl-es:bash) printf '%s' 'Instala primeiro Bash 4 ou posterior.';;
    gl-es:health) printf '%s' '4/4 · Comprobando os servizos de OVOS';;
    gl-es:servicesOk) printf '%s' 'Os servizos esperados están en marcha. Isto aínda non confirma que funcionen o micrófono e o altofalante.';;
    gl-es:servicesMissing) printf '%s' 'Algúns servizos aínda non están en marcha. Agarda ao arranque ou reinicia se cho pediron e volve comprobalo.';;
    gl-es:servicesUnknown) printf '%s' 'Aquí non se poden comprobar os servizos automaticamente. A instalación e a voz seguen sen verificar.';;
    gl-es:checkMenu) printf '%s' 'Seguinte: 1 = probar altofalante e micrófono, 2 = comprobar servizos de novo, Intro = máis tarde: ';;
    gl-es:audioTest) printf '%s' 'OVOS vai dicir unha frase curta. Escoita o dispositivo.';;
    gl-es:audioQuestion) printf '%s' 'Escoitáchela? 1 = si, 2 = repetir, Intro = máis tarde: ';;
    gl-es:audioOk) printf '%s' 'Confirmaches que o altofalante funciona.';;
    gl-es:audioFailed) printf '%s' 'A proba de son non puido conectar con OVOS. Revisa os servizos, o volume e o dispositivo de son escollido.';;
    gl-es:voiceIntro) printf '%s' 'Fala agora preto do micrófono. Se cambiaches a palabra de activación, usa a túa:';;
    gl-es:voicePhrase) printf '%s' 'Hey Mycroft, que hora é?';;
    gl-es:voiceQuestion) printf '%s' 'OVOS respondeu correctamente? 1 = si, 2 = repetir, Intro = máis tarde: ';;
    gl-es:voiceOk) printf '%s' 'Confirmaches a primeira resposta de voz. Goza de OVOS!';;
    gl-es:incomplete) printf '%s' 'A comprobación queda pendente. Podes retomala co comando anterior.';;
    gl-es:customVoice) printf '%s' 'Non escolliches as habilidades incluídas. Proba un comando dunha habilidade que instalases; a pregunta sobre a hora pode non estar dispoñible.';;
    gl-es:hub) printf '%s' 'Este dispositivo é un servidor central. Proba o micrófono e o altofalante nun satélite conectado.';;
    gl-es:help) printf '%s' 'Precisas axuda? Chat da comunidade: https://matrix.to/#/#openvoiceos:matrix.org';;
    gl-es:closed) printf '%s' 'Non hai un terminal interactivo dispoñible. Executa o comando de comprobación nun terminal cando queiras continuar.';;
    gl-es:unsafeConfig) printf '%s' 'O cartafol de configuración contén un ficheiro ou unha ligazón inesperados. Móveos a outro lugar e téntao de novo. Non se substituíron os teus axustes.';;
    gl-es:locked) printf '%s' 'Hai unha instalación en curso ou un intento interrompido deixou un bloqueo. Primeiro comproba que non haxa ningunha instalación en marcha. Despois elimina este cartafol de bloqueo e téntao de novo:';;
    gl-es:runtimeBackup) printf '%s' 'Ferramentas de instalación anteriores gardadas en:';;
    hi-in:bits) printf '%s' 'OVOS के लिए 64-बिट ऑपरेटिंग सिस्टम चाहिए। कोई बदलाव नहीं किया गया।';;
    hi-in:invalid) printf '%s' 'सेटअप कोड गलत या अधूरा है। विज़ार्ड से नया कमांड कॉपी करें।';;
    hi-in:expired) printf '%s' 'एक घंटा पूरा होने पर यह कोड समाप्त हो गया। विज़ार्ड में नया कोड बनाएँ।';;
    hi-in:future) printf '%s' 'इस कोड का समय भविष्य का है। घड़ी जाँचें और नया कोड बनाएँ।';;
    hi-in:clock) printf '%s' 'सिस्टम की घड़ी गलत है या उपलब्ध नहीं है। आगे बढ़ने से पहले इसे ठीक करें।';;
    hi-in:regular) printf '%s' 'यह कमांड अपने सामान्य खाते से चलाएँ, sudo के बिना।';;
    hi-in:mac) printf '%s' 'यह सेटअप Mac के लिए है। उस Mac पर Terminal खोलें।';;
    hi-in:linux) printf '%s' 'इसे अपने Linux डिवाइस पर चलाएँ। Windows पर WSL2 में Ubuntu खोलें।';;
    hi-in:dependency) printf '%s' 'पहले यह ज़रूरी टूल इंस्टॉल करें, फिर कमांड दोबारा पेस्ट करें:';;
    hi-in:existing) printf '%s' 'पहले ~/ovos-installer को दूसरी जगह ले जाएँ। मौजूदा फ़ोल्डर नहीं बदला गया है।';;
    hi-in:checking) printf '%s' '1/4 · डिवाइस की जाँच';;
    hi-in:download) printf '%s' '2/4 · इंस्टॉलर डाउनलोड हो रहा है';;
    hi-in:downloadFailed) printf '%s' 'डाउनलोड नहीं हो पाया। इंटरनेट जाँचें और नया कमांड कॉपी करें। आपकी सेटिंग नहीं बदली गई हैं।';;
    hi-in:revision) printf '%s' 'इंस्टॉलर के संस्करण की पुष्टि नहीं हो सकी। आपकी सेटिंग नहीं बदली गई हैं।';;
    hi-in:backup) printf '%s' 'पुरानी सेटिंग की प्रति यहाँ रखी गई है:';;
    hi-in:installing) printf '%s' '3/4 · OVOS इंस्टॉल हो रहा है। इसमें समय लग सकता है; नीचे दिए निर्देश देखें।';;
    hi-in:installFailed) printf '%s' 'इंस्टॉलेशन पूरा नहीं हुआ। ऊपर की त्रुटि और /var/log/ovos-installer.log देखें। पुरानी सेटिंग की प्रति सुरक्षित है। संदेह हो तो दोबारा कोशिश करने से पहले समुदाय से मदद लें।';;
    hi-in:installReturned) printf '%s' 'इंस्टॉलर का चरण समाप्त हुआ। सेटअप पूरा मानने से पहले सेवाएँ जाँचें और बोलकर आज़माएँ।';;
    hi-in:resume) printf '%s' 'रीस्टार्ट के बाद या दोबारा जाँचने के लिए चलाएँ:';;
    hi-in:cancelHint) printf '%s' 'रोकने के लिए किसी भी फ़ील्ड में :cancel लिखें या Ctrl+C दबाएँ। बाकी जानकारी ठीक करते समय सही भरे फ़ील्ड बने रहते हैं।';;
    hi-in:cancelled) printf '%s' 'रद्द किया गया। इंस्टॉलेशन शुरू नहीं हुआ और पुरानी सेटिंग अभी भी लागू हैं।';;
    hi-in:required) printf '%s' 'यह फ़ील्ड भरना ज़रूरी है। दोबारा कोशिश करें या :cancel लिखें।';;
    hi-in:urlError) printf '%s' 'होस्ट सहित पूरा http:// या https:// पता दें। उसमें खाली जगह, जुड़ा हुआ पासवर्ड या फ़्रैगमेंट न हो।';;
    hi-in:haUrl) printf '%s' 'Home Assistant का पता: ';;
    hi-in:haToken) printf '%s' 'Home Assistant का लंबे समय तक मान्य टोकन: ';;
    hi-in:llmLocal) printf '%s' 'अपने मौजूदा स्थानीय मॉडल सर्वर से जुड़ें, जो OpenAI API के साथ काम करता हो।';;
    hi-in:llmOnline) printf '%s' 'अपने चुने हुए ऑनलाइन प्रदाता से जुड़ें, जो OpenAI API के साथ काम करता हो। उपयोग का शुल्क लग सकता है।';;
    hi-in:llmUrl) printf '%s' 'OpenAI-संगत API का पता: ';;
    hi-in:llmModel) printf '%s' 'मॉडल का नाम: ';;
    hi-in:llmKey) printf '%s' 'API कुंजी (या बिना कुंजी वाले स्थानीय सर्वर का माँगा हुआ मान): ';;
    hi-in:bash) printf '%s' 'पहले Bash 4 या नया संस्करण इंस्टॉल करें।';;
    hi-in:health) printf '%s' '4/4 · OVOS सेवाओं की जाँच';;
    hi-in:servicesOk) printf '%s' 'ज़रूरी सेवाएँ चल रही हैं। इससे अभी माइक्रोफ़ोन या स्पीकर के काम करने की पुष्टि नहीं होती।';;
    hi-in:servicesMissing) printf '%s' 'कुछ सेवाएँ अभी नहीं चल रही हैं। शुरू होने का इंतज़ार करें या माँगे जाने पर रीस्टार्ट करें, फिर जाँचें।';;
    hi-in:servicesUnknown) printf '%s' 'यहाँ सेवाओं की अपने-आप जाँच उपलब्ध नहीं है। इंस्टॉलेशन और आवाज़ की पुष्टि अभी बाकी है।';;
    hi-in:checkMenu) printf '%s' 'आगे: 1 = स्पीकर और माइक्रोफ़ोन जाँचें, 2 = सेवाएँ फिर जाँचें, Enter = बाद में: ';;
    hi-in:audioTest) printf '%s' 'OVOS एक छोटा वाक्य बोलेगा। अपने डिवाइस को सुनें।';;
    hi-in:audioQuestion) printf '%s' 'क्या आपने सुना? 1 = हाँ, 2 = फिर कोशिश करें, Enter = बाद में: ';;
    hi-in:audioOk) printf '%s' 'आपने स्पीकर के काम करने की पुष्टि की।';;
    hi-in:audioFailed) printf '%s' 'आवाज़ की जाँच OVOS से नहीं जुड़ सकी। सेवाएँ, वॉल्यूम और चुना हुआ ऑडियो डिवाइस जाँचें।';;
    hi-in:voiceIntro) printf '%s' 'अब माइक्रोफ़ोन के पास बोलें। अगर आपने जगाने वाला शब्द बदला है तो अपना शब्द बोलें:';;
    hi-in:voicePhrase) printf '%s' 'Hey Mycroft, समय क्या हुआ?';;
    hi-in:voiceQuestion) printf '%s' 'क्या OVOS ने सही जवाब दिया? 1 = हाँ, 2 = फिर कोशिश करें, Enter = बाद में: ';;
    hi-in:voiceOk) printf '%s' 'आपने पहले बोले गए जवाब की पुष्टि की। OVOS का आनंद लें!';;
    hi-in:incomplete) printf '%s' 'जाँच अभी अधूरी है। ऊपर दिए कमांड से इसे बाद में जारी रख सकते हैं।';;
    hi-in:customVoice) printf '%s' 'आपने साथ मिलने वाले कौशल नहीं चुने हैं। अपने इंस्टॉल किए कौशल का कमांड आज़माएँ; समय वाला सवाल शायद उपलब्ध न हो।';;
    hi-in:hub) printf '%s' 'यह डिवाइस एक हब है। जुड़े हुए वॉइस सैटेलाइट पर माइक्रोफ़ोन और स्पीकर जाँचें।';;
    hi-in:help) printf '%s' 'मदद चाहिए? समुदाय से बात करें: https://matrix.to/#/#openvoiceos:matrix.org';;
    hi-in:closed) printf '%s' 'इंटरैक्टिव टर्मिनल उपलब्ध नहीं है। तैयार होने पर जाँच वाला कमांड किसी टर्मिनल में चलाएँ।';;
    hi-in:unsafeConfig) printf '%s' 'सेटअप फ़ोल्डर में कोई अनपेक्षित फ़ाइल या लिंक है। उसे दूसरी जगह ले जाएँ, फिर कोशिश करें। आपकी सेटिंग नहीं बदली गई हैं।';;
    hi-in:locked) printf '%s' 'कोई इंस्टॉलेशन चल रहा है, या बीच में रुके प्रयास का लॉक रह गया है। पहले सुनिश्चित करें कि कोई इंस्टॉलेशन नहीं चल रहा है। फिर यह लॉक फ़ोल्डर हटाएँ और दोबारा कोशिश करें:';;
    hi-in:runtimeBackup) printf '%s' 'इंस्टॉल करने वाले पिछले टूल यहाँ सुरक्षित हैं:';;
    kab-dz:bits) printf '%s' 'OVOS yesra anagraw n wammud 64 ibiten. Ulac abeddel i yettwaxedmen.';;
    kab-dz:invalid) printf '%s' 'Tangalt n usbeddi mačči d tameɣtut neɣ ur temmid ara. Nɣel taladna tamaynut seg umallal.';;
    kab-dz:expired) printf '%s' 'Tangalt-a tfukk seld yiwen n usrag. Snulfu-d tayeḍ deg umallal.';;
    kab-dz:future) printf '%s' 'Azemz n tengalt-a yella deg yimal. Senqed tamrilt, syen snulfu-d tangalt tamaynut.';;
    kab-dz:clock) printf '%s' 'Tamrilt n unagraw mačči d tameɣtut neɣ ulac-itt. Seɣti-tt send ad tkemmleḍ.';;
    kab-dz:regular) printf '%s' 'Selkem taladna-a s umiḍan-ik amagnu, war sudo.';;
    kab-dz:mac) printf '%s' 'Asbeddi-a i Mac. Ldi Terminal deg Mac-nni.';;
    kab-dz:linux) printf '%s' 'Selkem aya deg yibenk-ik Linux. Deg Windows, ldi Ubuntu deg WSL2.';;
    kab-dz:dependency) printf '%s' 'Sbedd allal-a, syen senteḍ tikkelt-nniḍen taladna:';;
    kab-dz:existing) printf '%s' 'Senkez qbel ~/ovos-installer ɣer umḍiq-nniḍen. Akaram yellan ur yettwabeddel ara.';;
    kab-dz:checking) printf '%s' '1/4 · Asenqed n yibenk';;
    kab-dz:download) printf '%s' '2/4 · Asider n usebdad';;
    kab-dz:downloadFailed) printf '%s' 'Asider ur yeddi ara. Senqed tuqqna Internet, syen nɣel taladna tamaynut. Iɣewwaren ur ttwasemselsin ara.';;
    kab-dz:revision) printf '%s' 'Lqem n usebdad ur yezmir ara ad yettwasenqed. Iɣewwaren ur ttwasemselsin ara.';;
    kab-dz:backup) printf '%s' 'Anɣel n yiɣewwaren iqburen yettwasekles da:';;
    kab-dz:installing) printf '%s' '3/4 · Asbeddi n OVOS. Aya yezmer ad yeṭṭef kra n wakud; ḍfer iwellihen ddaw-a.';;
    kab-dz:installFailed) printf '%s' 'Asbeddi ur ifuk ara. Wali tuccḍa nnig-a akked /var/log/ovos-installer.log. Anɣel n yiɣewwaren yeqqim. Ma tesɛiḍ ccek, suter tallalt i tmezdagnut send ad tɛerḍeḍ tikkelt-nniḍen.';;
    kab-dz:installReturned) printf '%s' 'Amur n usebdad ifuk. Senqed imeẓla, ɛreḍ taɣect send ad tḥesbeḍ belli asbeddi yemmed.';;
    kab-dz:resume) printf '%s' 'Seld aɛiwed n usenker, neɣ i usenqed-nniḍen, selkem:';;
    kab-dz:cancelHint) printf '%s' 'Aru :cancel deg yal urti neɣ ssed Ctrl+C i usefsex. Tirririt tameɣtut teqqim mi tseɣtayeḍ tiyaḍ.';;
    kab-dz:cancelled) printf '%s' 'Yettwasefsex. Asbeddi ur yebdi ara, iɣewwaren iqburen qqimen d urmiden.';;
    kab-dz:required) printf '%s' 'Urti-a ilaq ad yettwaččar. Ɛreḍ tikkelt-nniḍen neɣ aru :cancel.';;
    kab-dz:urlError) printf '%s' 'Sekcem tansa http:// neɣ https:// yemden s usenneftaɣ, war tallunt, awal uffir deg-s neɣ aḥric.';;
    kab-dz:haUrl) printf '%s' 'Tansa n Home Assistant: ';;
    kab-dz:haToken) printf '%s' 'Ajiṭun n unekcum ɣezzifen n Home Assistant: ';;
    kab-dz:llmLocal) printf '%s' 'Qqen ɣer uqeddac-ik adigan n umudam yellan, amṣada akked API OpenAI.';;
    kab-dz:llmOnline) printf '%s' 'Qqen ɣer usaǧǧaw srid i tferneḍ, amṣada akked API OpenAI. Aseqdec yezmer ad yesɛu azal.';;
    kab-dz:llmUrl) printf '%s' 'Tansa n API amṣada akked OpenAI: ';;
    kab-dz:llmModel) printf '%s' 'Isem n umudam: ';;
    kab-dz:llmKey) printf '%s' 'Tasarut API (neɣ azal i yesra uqeddac adigan war tasarut): ';;
    kab-dz:bash) printf '%s' 'Sbedd qbel Bash 4 neɣ lqem amaynut ugar.';;
    kab-dz:health) printf '%s' '4/4 · Asenqed n yimeẓla OVOS';;
    kab-dz:servicesOk) printf '%s' 'Imeẓla yetturaǧun teddun. Aya ur d-yessebtat ara belli amikru akked usmeɣri n yimesli teddun.';;
    kab-dz:servicesMissing) printf '%s' 'Kra n yimeẓla ur tteddun ara yakan. Arǧu asenker, neɣ ales asenker ma tettwasutreḍ, syen senqed tikkelt-nniḍen.';;
    kab-dz:servicesUnknown) printf '%s' 'Asenqed awurman n yimeẓla ulac-it da. Asbeddi akked taɣect mazal ur ttwasenqden ara.';;
    kab-dz:checkMenu) printf '%s' 'Ɣer zdat: 1 = ɛreḍ imesli akked umikru, 2 = senqed imeẓla tikkelt-nniḍen, Enter = ticki: ';;
    kab-dz:audioTest) printf '%s' 'OVOS ad d-yini tafyirt tawezlant. Ḥess i yibenk-ik.';;
    kab-dz:audioQuestion) printf '%s' 'Tesliḍ-as? 1 = ih, 2 = ales aɛraḍ, Enter = ticki: ';;
    kab-dz:audioOk) printf '%s' 'Tessebteḍ belli asmeɣri n yimesli iteddu.';;
    kab-dz:audioFailed) printf '%s' 'Aɛraḍ n yimesli ur yezmir ara ad iqqen ɣer OVOS. Senqed imeẓla, aswir n yimesli akked yibenk n yimesli yettwafernen.';;
    kab-dz:voiceIntro) printf '%s' 'Tura mmeslay ɣer tama n umikru. Ma tbeddleḍ awal n usaki, seqdec win-ik:';;
    kab-dz:voicePhrase) printf '%s' 'Hey Mycroft, acḥal n usrag?';;
    kab-dz:voiceQuestion) printf '%s' 'OVOS yerra-d akken iwata? 1 = ih, 2 = ales aɛraḍ, Enter = ticki: ';;
    kab-dz:voiceOk) printf '%s' 'Tessebteḍ tiririt tamezwarut s taɣect. Zhu s OVOS!';;
    kab-dz:incomplete) printf '%s' 'Asenqed mazal ur ifuk ara. Tzemreḍ ad tkemmleḍ s taladna nnig-a.';;
    kab-dz:customVoice) printf '%s' 'Ur tferneḍ ara tizemmar yeddan. Ɛreḍ taladna n tezmert i tesbeddeḍ; asteqsi ɣef usrag yezmer ur yelli ara.';;
    kab-dz:hub) printf '%s' 'Ibenk-a d alemmas. Senqed amikru akked usmeɣri n yimesli deg usatelit yeqqnen.';;
    kab-dz:help) printf '%s' 'Tesriḍ tallalt? Asqerdec n tmezdagnut: https://matrix.to/#/#openvoiceos:matrix.org';;
    kab-dz:closed) printf '%s' 'Ulac tadiwent amyigawant. Selkem taladna n usenqed deg tadiwent mi ara theggiḍ.';;
    kab-dz:unsafeConfig) printf '%s' 'Akaram n useɣwer yesɛa afaylu neɣ aseɣwen ur nettwarǧi ara. Senkez-it ɣer umḍiq-nniḍen, syen ɛreḍ tikkelt-nniḍen. Iɣewwaren-ik ur ttwasemselsin ara.';;
    kab-dz:locked) printf '%s' 'Asbeddi la iteddu, neɣ asbeddi yeḥbes yeǧǧa akaram n usekṛu. Senqed qbel belli ulac asbeddi iteddun. Syen kkes akaram-a n usekṛu, ɛreḍ tikkelt-nniḍen:';;
    kab-dz:runtimeBackup) printf '%s' 'Allalen n usebded iqburen ttwaskelsen deg:';;
    *) printf '%s' 'OVOS: unknown message';;
  esac
}
say() { message "$1"; printf '\n'; }
# Emit literal shell definitions; expansion occurs only in the resulting checker.
# shellcheck disable=SC2016
write_messages() {
  printf '%s\n' 'message() {' '  case "$1" in'
  for ovos_key in audioFailed audioOk audioQuestion audioTest backup bash bits cancelHint cancelled checkMenu checking clock closed customVoice dependency download downloadFailed existing expired future haToken haUrl health help hub incomplete installFailed installReturned installing invalid linux llmKey llmLocal llmModel llmOnline llmUrl locked mac regular required resume revision runtimeBackup servicesMissing servicesOk servicesUnknown unsafeConfig urlError voiceIntro voiceOk voicePhrase voiceQuestion; do
    printf '%s' "    $ovos_key) printf '%s' '"
    message "$ovos_key" | sed "s/'/'\\\\''/g"
    printf '%s\n' "';;"
  done
  printf '%s\n' "    *) printf '%s' 'OVOS: unknown message';;" '  esac' '}'
  printf '%s\n' 'say() { message "$1"; printf "\n"; }'
}

ovos_locale=en-us
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}" in
  fr*) ovos_locale=fr-fr;; de*) ovos_locale=de-de;; es*) ovos_locale=es-es;; it*) ovos_locale=it-it;;
  nl*) ovos_locale=nl-nl;; pt*) ovos_locale=pt-pt;; ca*) ovos_locale=ca-es;; eu*) ovos_locale=eu-es;;
  gl*) ovos_locale=gl-es;; hi*) ovos_locale=hi-in;; kab*) ovos_locale=kab-dz;;
esac
fail_message() { say "$1" >&2; exit 1; }
fail() {
  # Preserve precise English decoder diagnostics. Localize before any side effect.
  if [ "$ovos_locale" = en-us ]; then printf '%s\n' "$*" >&2; exit 1; fi
  case "$*" in
    *64-bit*) fail_message bits;; *expired*) fail_message expired;;
    *future-dated*) fail_message future;; *clock*|*timestamp*) fail_message clock;;
    *) fail_message invalid;;
  esac
}

# Also protects timestamp arithmetic on shells with a 32-bit userland.
[ "$(getconf LONG_BIT 2>/dev/null || true)" = 64 ] || fail 'OVOS needs a 64-bit operating system. No changes were made.'
ovos_mode=install
case "${1:-}" in
  --decode|--scenario) ovos_mode=${1#--}; shift;;
esac
ovos_track=''
if [ "$#" = 3 ] && [ "$2" = --track ]; then
  ovos_track=$3
  [ "${#ovos_track}" = 64 ] || fail 'Invalid installation status token. Copy the command again.'
  case "$ovos_track" in *[!0-9a-f]*) fail 'Invalid installation status token. Copy the command again.';; esac
elif [ "$#" != 1 ]; then
  fail 'Paste the complete command from OVOS Start, including your setup code.'
fi
# Minimal, optional progress reporting. Never accept arbitrary destinations,
# messages, logs, credentials or device identifiers from installer output.
valid_error_url() {
  case "$1" in https://paste.uoi.io/*) :;; *) return 1;; esac
  ovos_error_id=${1#https://paste.uoi.io/}
  ovos_error_id=${ovos_error_id%/}
  case "$ovos_error_id" in ''|*[!A-Za-z0-9_-]*) return 1;; esac
  [ "${#ovos_error_id}" -le 128 ]
}

report_status() {
  [ -n "${ovos_track:-}" ] || return 0
  [ "${#ovos_track}" = 64 ] || return 0
  case "$ovos_track" in *[!0-9a-f]*) return 0;; esac
  case "$1" in started|downloading|installing|installed|services_ready|voice_ready|needs_attention|failed|cancelled) :;; *) return 0;; esac
  ovos_error_field=''
  if [ "$1" = failed ] && valid_error_url "${2:-}"; then
    ovos_error_field=",\\\"errorUrl\\\":\\\"$2\\\""
  fi
  command -v curl >/dev/null 2>&1 || return 0
  # -q must be first: an inherited curlrc must not enable tracing or redirects.
  # Keep the bearer out of argv. Ignore every transport failure; installation
  # never depends on the browser or status relay being reachable.
  curl -q --config - --proto '=https' --connect-timeout 2 --max-time 3 --silent --fail --output /dev/null <<OVOS_STATUS >/dev/null 2>&1 || :
url = "https://start-api.smartgic.io/v1/events"
request = "POST"
header = "Authorization: Bearer $ovos_track"
header = "Content-Type: application/json"
data = "{\"event\":\"$1\"$ovos_error_field}"
OVOS_STATUS
}

load_status_token() {
  ovos_track=''
  for ovos_status_path in "$HOME/.config" "$HOME/.config/ovos-installer"; do
    [ -d "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ] || return 0
  done
  ovos_status_path="$HOME/.config/ovos-installer/status-token"
  if [ -f "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ]; then
    IFS= read -r ovos_track < "$ovos_status_path" || ovos_track=''
  fi
}

report_saved_install() {
  [ -n "${ovos_track:-}" ] || return 0
  for ovos_status_path in "$HOME/.config" "$HOME/.config/ovos-installer"; do
    [ -d "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ] || return 0
  done
  ovos_status_path="$HOME/.config/ovos-installer/status-installed"
  if [ -f "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ]; then
    ovos_status_receipt=''
    IFS= read -r ovos_status_receipt < "$ovos_status_path" || return 0
    [ "$ovos_status_receipt" = "$ovos_track" ] || return 0
    report_status installed
  fi
}

case "$1" in
  ????????|????-????) fail 'This legacy setup code has no expiry. Generate a new one-hour code in OVOS Start.';;
  ????????????????|????-????-????-????) :;;
  *) fail 'That setup code is not complete. Generate a new code in OVOS Start.';;
esac
ovos_code=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -d '-')
[ "${#ovos_code}" = 16 ] || fail 'Invalid setup code.'
ovos_alphabet=0123456789ABCDEFGHJKMNPQRSTVWXYZ
# Decode bytes as they arrive: the 80-bit wire word never enters shell arithmetic.
ovos_buffer=0
ovos_bits=0
ovos_byte_index=0
ovos_body=0
ovos_issued=0
ovos_crc=0
ovos_supplied_crc=0
ovos_rest=$ovos_code
while [ -n "$ovos_rest" ]; do
  ovos_char=${ovos_rest%"${ovos_rest#?}"}
  ovos_rest=${ovos_rest#?}
  case "$ovos_alphabet" in
    *"$ovos_char"*) ovos_prefix=${ovos_alphabet%%"$ovos_char"*}; ovos_digit=${#ovos_prefix};;
    *) fail 'That setup code contains an unexpected character. Copy it again.';;
  esac
  ovos_buffer=$((ovos_buffer * 32 + ovos_digit))
  ovos_bits=$((ovos_bits + 5))
  if [ "$ovos_bits" -ge 8 ]; then
    ovos_bits=$((ovos_bits - 8))
    ovos_byte=$(((ovos_buffer >> ovos_bits) & 255))
    ovos_buffer=$((ovos_buffer & ((1 << ovos_bits) - 1)))
    if [ "$ovos_byte_index" -lt 4 ]; then
      ovos_body=$((ovos_body * 256 + ovos_byte))
    elif [ "$ovos_byte_index" -lt 9 ]; then
      ovos_issued=$((ovos_issued * 256 + ovos_byte))
    else
      ovos_supplied_crc=$ovos_byte
    fi
    if [ "$ovos_byte_index" -lt 9 ]; then
      ovos_crc=$((ovos_crc ^ ovos_byte))
      ovos_bit=0
      while [ "$ovos_bit" -lt 8 ]; do
        if [ "$ovos_crc" -ge 128 ]; then ovos_crc=$((((ovos_crc * 2) ^ 7) & 255)); else ovos_crc=$((ovos_crc * 2)); fi
        ovos_bit=$((ovos_bit + 1))
      done
    fi
    ovos_byte_index=$((ovos_byte_index + 1))
  fi
done
[ "$ovos_crc" = "$ovos_supplied_crc" ] || fail 'That setup code looks mistyped. Copy it again from OVOS Start.'
# A checksum-verified locale can explain expiry in the chosen language.
case "$(((ovos_body >> 18) & 15))" in
  0) ovos_locale=en-us;; 1) ovos_locale=fr-fr;; 2) ovos_locale=de-de;; 3) ovos_locale=es-es;;
  4) ovos_locale=it-it;; 5) ovos_locale=nl-nl;; 6) ovos_locale=pt-pt;; 7) ovos_locale=ca-es;;
  8) ovos_locale=eu-es;; 9) ovos_locale=gl-es;; 10) ovos_locale=hi-in;; 11) ovos_locale=kab-dz;;
esac
[ "$((ovos_body >> 28))" = 2 ] || fail 'This setup code needs a different launcher version. Generate a new code in OVOS Start.'
[ "$ovos_issued" -gt 0 ] || fail 'Invalid setup timestamp. Check the clock and generate a new code.'
ovos_now=$(date +%s 2>/dev/null) || fail 'The system clock is unavailable. Correct it before using a setup code.'
case "$ovos_now" in ''|*[!0-9]*|0*) fail 'The system clock is invalid. Correct it before using a setup code.';; esac
if [ "${#ovos_now}" -gt 13 ] || [ "$ovos_now" -gt 1099511627775 ]; then fail 'The system clock is invalid. Correct it before using a setup code.'; fi
[ "$ovos_issued" -le "$ovos_now" ] || fail 'This setup code is future-dated. Check the clock and generate a new code.'
[ "$ovos_now" -lt "$((ovos_issued + 3600))" ] || fail 'This setup code expired after one hour. Generate a new code in OVOS Start.'
ovos_payload=$((ovos_body & 268435455))
ovos_remaining=28

# Read a fixed-width enum. Values come only from this trusted script, never eval.
take() {
  ovos_remaining=$((ovos_remaining - $1))
  ovos_index=$(((ovos_payload >> ovos_remaining) & ((1 << $1) - 1)))
  shift
  [ "$ovos_index" -lt "$#" ] || fail 'This setup code contains an unsupported choice.'
  while [ "$ovos_index" -gt 0 ]; do shift; ovos_index=$((ovos_index - 1)); done
  ovos_value=$1
}
take 4 pi computer mark1 mark2 devkit jetson server mac windows other; ovos_device=$ovos_value
take 2 ready tinker hub; ovos_experience=$ovos_value
take 4 en-us fr-fr de-de es-es it-it nl-nl pt-pt ca-es eu-es gl-es hi-in kab-dz; ovos_locale=$ovos_value
take 1 virtualenv containers; ovos_method=$ovos_value
take 1 testing alpha; ovos_channel=$ovos_value
take 2 guided tinker expert; ovos_expertise=$ovos_value
take 2 auto public local; ovos_speech=$ovos_value
take 2 unknown under8 8plus; ovos_memory=$ovos_value
take 2 unknown arm64 avx2 intel-mac; ovos_cpu=$ovos_value
take 2 unknown older pi5; ovos_pi=$ovos_value
take 2 off local online; ovos_llm=$ovos_value
take 1 false true; ovos_extra=$ovos_value
take 1 false true; ovos_telemetry=$ovos_value
take 1 false true; ovos_skills=$ovos_value
take 1 false true; ovos_ha=$ovos_value

invalid() { fail 'These setup choices do not fit together. Open OVOS Start and make a new setup.'; }
case "$ovos_device:$ovos_experience" in server:ready|server:tinker|mark1:hub|mark2:hub|devkit:hub) invalid;; esac
case "$ovos_device" in
  mark2|devkit|mac) [ "$ovos_method:$ovos_channel" = virtualenv:alpha ] || invalid;;
  mark1|windows) [ "$ovos_method" = virtualenv ] || invalid;;
esac
[ "$ovos_extra:$ovos_skills" != true:false ] || invalid
if [ "$ovos_experience" = hub ]; then
  [ "$ovos_speech:$ovos_ha:$ovos_llm" = auto:false:off ] || invalid
  [ "$ovos_method:$ovos_extra" != containers:true ] || invalid
fi
if [ "$ovos_speech" = local ]; then
  [ "$ovos_method:$ovos_channel:$ovos_memory" = virtualenv:alpha:8plus ] || invalid
  case "$ovos_locale" in hi-in|kab-dz) invalid;; esac
  case "$ovos_device" in
    mark1|mark2|devkit) invalid;;
    pi) [ "$ovos_pi:$ovos_cpu" = pi5:arm64 ] || invalid;;
    jetson|mac) [ "$ovos_cpu" = arm64 ] || invalid;;
  esac
  case "$ovos_cpu" in arm64|avx2) :;; *) invalid;; esac
fi

scenario() {
  printf '%s\n' '# Created with OVOS Start · contract checked 2026-10-06' 'uninstall: false' "method: $ovos_method" "channel: $ovos_channel"
  if [ "$ovos_experience" = hub ]; then printf '%s\n' 'profile: server'; else printf '%s\n' 'profile: ovos'; fi
  [ "$ovos_speech" = auto ] || printf '%s\n' "speech_engine: $ovos_speech"
  ovos_gui=false
  case "$ovos_device" in mark2|devkit) ovos_gui=true; printf '%s\n' "hardware: $ovos_device";; esac
  ovos_has_llm=false; [ "$ovos_llm" = off ] || ovos_has_llm=true
  ovos_pi_tuning=false
  case "$ovos_device" in pi|mark1|mark2|devkit) ovos_pi_tuning=true;; esac
  printf '%s\n' 'features:' "  skills: $ovos_skills" "  extra_skills: $ovos_extra" "  gui: $ovos_gui" "  homeassistant: $ovos_ha" "  llm: $ovos_has_llm" "raspberry_pi_tuning: $ovos_pi_tuning" "share_telemetry: $ovos_telemetry" 'share_usage_telemetry: false'
}
if [ "$ovos_mode" = decode ]; then
  printf '{"device":"%s","experience":"%s","locale":"%s","method":"%s","channel":"%s","expertise":"%s","speech":"%s","memory":"%s","cpu":"%s","piModel":"%s","llmMode":"%s","extraSkills":%s,"telemetry":%s,"skills":%s,"homeassistant":%s}\n' "$ovos_device" "$ovos_experience" "$ovos_locale" "$ovos_method" "$ovos_channel" "$ovos_expertise" "$ovos_speech" "$ovos_memory" "$ovos_cpu" "$ovos_pi" "$ovos_llm" "$ovos_extra" "$ovos_telemetry" "$ovos_skills" "$ovos_ha"
  exit 0
fi
if [ "$ovos_mode" = scenario ]; then scenario; exit 0; fi

ovos_tmp=''
ovos_error_receipt=''
ovos_lock=''
ovos_installed=false
ovos_cleanup_result=0
# The private receipt survives upstream checkout cleanup. It contains one
# consented paste URL, never arbitrary terminal output or a previous attempt.
read_error_report() (
  [ -n "$1" ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 0
  ovos_error_size=$(wc -c < "$1") || exit 0
  [ "$ovos_error_size" -gt 0 ] && [ "$ovos_error_size" -le 151 ] || exit 0
  IFS= read -r ovos_error_url < "$1" || exit 0
  # Reject extra lines, including empty lines stripped by command substitution.
  [ "$ovos_error_size" -eq "$((${#ovos_error_url} + 1))" ] || exit 0
  valid_error_url "$ovos_error_url" || exit 0
  printf '%s' "$ovos_error_url"
)

cleanup() {
  if [ "$ovos_installed" != true ] && [ "$1" -ne 0 ]; then
    case "$1" in
      129|130|143) report_status cancelled;;
      *) report_status failed "$(read_error_report "$ovos_error_receipt")";;
    esac
  fi
  [ -z "$ovos_tmp" ] || rm -rf "$ovos_tmp" || :
  [ -z "$ovos_lock" ] || rmdir "$ovos_lock" 2>/dev/null || :
}
trap 'ovos_cleanup_result=$?; cleanup "$ovos_cleanup_result"; exit "$ovos_cleanup_result"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

say checking
[ "$(id -u)" -ne 0 ] || fail_message regular
if [ "$ovos_device" = mac ]; then
  [ "$(uname -s)" = Darwin ] || fail_message mac
else
  [ "$(uname -s)" = Linux ] || fail_message linux
fi
for ovos_program in git sudo; do command -v "$ovos_program" >/dev/null 2>&1 || { say dependency >&2; printf '%s\n' "$ovos_program" >&2; exit 1; }; done
if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then fail_message unsafeConfig; fi
case "$HOME" in /*) :;; *) fail_message unsafeConfig;; esac
if [ -e "$HOME/ovos-installer" ] || [ -L "$HOME/ovos-installer" ]; then fail_message existing; fi
# Validate before downloading or replacing files: mv must not nest a helper
# inside a directory, and cp must not wait forever on a FIFO.
ovos_cfg="$HOME/.config/ovos-installer"
for ovos_path in "$HOME/.config" "$ovos_cfg"; do
  if [ -L "$ovos_path" ] || { [ -e "$ovos_path" ] && [ ! -d "$ovos_path" ]; }; then
    say unsafeConfig >&2; printf '%s\n' "$ovos_path" >&2; exit 1
  fi
done
for ovos_path in "$ovos_cfg/scenario.yaml" "$ovos_cfg/check-setup.sh" "$ovos_cfg/status-token" "$ovos_cfg/status-installed"; do
  if [ -L "$ovos_path" ] || { [ -e "$ovos_path" ] && [ ! -f "$ovos_path" ]; }; then
    say unsafeConfig >&2; printf '%s\n' "$ovos_path" >&2; exit 1
  fi
done
umask 077
mkdir -p "$ovos_cfg"
chmod 700 "$ovos_cfg"
# Upstream locks only after our handoff. Protect settings before activation too.
ovos_pending_lock="$ovos_cfg/.launcher-lock"
if ! mkdir "$ovos_pending_lock" 2>/dev/null; then
  # A double paste may carry the active install's capability. Do not poison its
  # browser session with a failure belonging only to this refused second run.
  ovos_track=''
  say locked >&2; printf '%s\n' "$ovos_pending_lock" >&2; exit 1
fi
ovos_lock=$ovos_pending_lock
ovos_tmp=$(mktemp -d "${TMPDIR:-/tmp}/ovos-start.XXXXXX")
if [ -n "$ovos_track" ]; then
  ovos_error_receipt="$ovos_tmp/error-report"
  : > "$ovos_error_receipt"
  chmod 600 "$ovos_error_receipt"
fi
report_status started
say download
report_status downloading
ovos_source="$ovos_tmp/source"
mkdir "$ovos_source"
# Git's inherited repository variables override -C and can otherwise redirect
# checkout into an unrelated working tree or index (for example from a hook).
# Clear only this launcher's process environment, retaining normal Git config,
# proxies and certificate settings. The installer child inherits the same reset.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE \
  GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_QUARANTINE_PATH \
  GIT_NAMESPACE GIT_PREFIX GIT_INTERNAL_SUPER_PREFIX GIT_IMPLICIT_WORK_TREE \
  GIT_SHALLOW_FILE GIT_REPLACE_REF_BASE GIT_GRAFT_FILE GIT_ATTR_SOURCE \
  GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
git -C "$ovos_source" init --quiet --template= || fail_message downloadFailed
# Never wait for an unexpected Git credential prompt; abort a stalled transfer.
# Every device uses the current main branch. The full ref excludes same-name
# tags; resolve it once so a concurrent upstream push cannot change this run.
GIT_TERMINAL_PROMPT=0 git -C "$ovos_source" -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 fetch --quiet --no-tags --depth=1 https://github.com/OpenVoiceOS/ovos-installer.git refs/heads/main || fail_message downloadFailed
ovos_revision=$(git -C "$ovos_source" rev-parse --verify 'FETCH_HEAD^{commit}') || fail_message revision
[ "${#ovos_revision}" = 40 ] || fail_message revision
case "$ovos_revision" in *[!0-9a-f]*) fail_message revision;; esac
git -C "$ovos_source" -c core.hooksPath=/dev/null checkout --quiet --detach "$ovos_revision" || fail_message downloadFailed
ovos_head=$(git -C "$ovos_source" rev-parse --verify 'HEAD^{commit}') || fail_message revision
[ "$ovos_head" = "$ovos_revision" ] || fail_message revision
# This notification plugin reads role metadata, never terminal logs or secrets.
# It only exists for tracked runs and leaves upstream stdout callbacks intact.
if [ -n "$ovos_track" ]; then
  mkdir "$ovos_source/.ovos-start-callbacks"
  cat > "$ovos_source/.ovos-start-callbacks/ovos_start_progress.py" <<'OVOS_ANSIBLE_PROGRESS'
"""Report fixed installer phases from successful Ansible role tasks only."""
from __future__ import annotations

import os
from pathlib import Path
import re
import stat
import subprocess

from ansible.plugins.callback import CallbackBase

PHASES = {
    "ovos_contract": 1, "ovos_hardware_mark1": 1, "ovos_hardware_mark2": 1,
    "ovos_facts": 1, "ovos_audio_tuning": 1, "ovos_network_tuning": 1,
    "ovos_storage_tuning": 1, "ovos_performance_tuning": 1,
    "ovos_sound": 1, "ovos_timezone": 1, "ovos_config": 1,
    "ovos_containers": 2, "ovos_virtualenv": 2, "ovos_python": 2,
    "ovos_services": 3, "ovos_finalize": 4,
}
EVENTS = ("", "stage_system", "stage_packages", "stage_services", "stage_finalize")


def report_phase(event: str) -> None:
    """Send one bounded, best-effort enum without exporting the private bearer."""
    if event not in EVENTS[1:]:
        return
    try:
        home = Path(os.environ.get("RUN_AS_HOME", ""))
        if not home.is_absolute():
            return
        for path in (home / ".config", home / ".config/ovos-installer"):
            if path.is_symlink() or not path.is_dir():
                return
        token_path = home / ".config/ovos-installer/status-token"
        fd = os.open(token_path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        with os.fdopen(fd, "r", encoding="ascii") as token_file:
            info = os.fstat(token_file.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                return
            token = token_file.read(66)
        if not re.fullmatch(r"[0-9a-f]{64}\n?", token):
            return
        config = (
            'url = "https://start-api.smartgic.io/v1/events"\n'
            'request = "POST"\n'
            f'header = "Authorization: Bearer {token.rstrip()}"\n'
            'header = "Content-Type: application/json"\n'
            f'data = "{{\\"event\\":\\"{event}\\"}}"\n'
        )
        subprocess.run(
            ["curl", "-q", "--config", "-", "--proto", "=https",
             "--connect-timeout", "2", "--max-time", "3", "--silent",
             "--fail", "--output", "/dev/null"],
            input=config, text=True, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, timeout=4, check=False,
        )
    except (OSError, UnicodeError, subprocess.SubprocessError):
        # Reporting cannot change installation or print a token-bearing exception.
        pass


class CallbackModule(CallbackBase):
    """A notification callback which never overrides Ansible's terminal output."""

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "ovos_start_progress"
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self, *args: object, **kwargs: object) -> None:
        """Start with no confirmed phase; each phase is attempted at most once."""
        super().__init__(*args, **kwargs)
        self.phase = 0

    def v2_runner_on_ok(self, result: object) -> None:
        """Advance on executed role tasks, ignoring names, arguments and output."""
        try:
            role = result._task._role
            phase = PHASES.get(role.get_name() if role else "", 0)
            if phase > self.phase:
                self.phase = phase
                report_phase(EVENTS[phase])
        except (AttributeError, TypeError):
            # Unknown upstream metadata means less detail, never guessed progress.
            pass

OVOS_ANSIBLE_PROGRESS
fi
# The download may take time; refuse a destination whose type changed meanwhile.
for ovos_path in "$HOME/.config" "$ovos_cfg"; do
  if [ ! -d "$ovos_path" ] || [ -L "$ovos_path" ]; then say unsafeConfig >&2; exit 1; fi
done
if [ -L "$ovos_cfg/scenario.yaml" ] || { [ -e "$ovos_cfg/scenario.yaml" ] && [ ! -f "$ovos_cfg/scenario.yaml" ]; }; then
  say unsafeConfig >&2; printf '%s\n' "$ovos_cfg/scenario.yaml" >&2; exit 1
fi
if [ -e "$ovos_cfg/scenario.yaml" ] || [ -L "$ovos_cfg/scenario.yaml" ]; then
  ovos_backup=$(mktemp "$ovos_cfg/scenario.yaml.backup.XXXXXX")
  cp -p "$ovos_cfg/scenario.yaml" "$ovos_backup"
  chmod 600 "$ovos_backup"
  say backup; printf '%s\n' "$ovos_backup"
fi
scenario > "$ovos_tmp/scenario.yaml"
printf '%s\n' "$ovos_track" > "$ovos_tmp/status-token"
printf '%s\n' "$ovos_track" > "$ovos_tmp/status-installed"
: > "$ovos_tmp/status-installed-empty"
chmod 600 "$ovos_tmp/status-token" "$ovos_tmp/status-installed" "$ovos_tmp/status-installed-empty"
write_messages > "$ovos_tmp/runtime.sh"
cat >> "$ovos_tmp/runtime.sh" <<'OVOS_RUNTIME'
# Minimal, optional progress reporting. Never accept arbitrary destinations,
# messages, logs, credentials or device identifiers from installer output.
valid_error_url() {
  case "$1" in https://paste.uoi.io/*) :;; *) return 1;; esac
  ovos_error_id=${1#https://paste.uoi.io/}
  ovos_error_id=${ovos_error_id%/}
  case "$ovos_error_id" in ''|*[!A-Za-z0-9_-]*) return 1;; esac
  [ "${#ovos_error_id}" -le 128 ]
}

report_status() {
  [ -n "${ovos_track:-}" ] || return 0
  [ "${#ovos_track}" = 64 ] || return 0
  case "$ovos_track" in *[!0-9a-f]*) return 0;; esac
  case "$1" in started|downloading|installing|installed|services_ready|voice_ready|needs_attention|failed|cancelled) :;; *) return 0;; esac
  ovos_error_field=''
  if [ "$1" = failed ] && valid_error_url "${2:-}"; then
    ovos_error_field=",\\\"errorUrl\\\":\\\"$2\\\""
  fi
  command -v curl >/dev/null 2>&1 || return 0
  # -q must be first: an inherited curlrc must not enable tracing or redirects.
  # Keep the bearer out of argv. Ignore every transport failure; installation
  # never depends on the browser or status relay being reachable.
  curl -q --config - --proto '=https' --connect-timeout 2 --max-time 3 --silent --fail --output /dev/null <<OVOS_STATUS >/dev/null 2>&1 || :
url = "https://start-api.smartgic.io/v1/events"
request = "POST"
header = "Authorization: Bearer $ovos_track"
header = "Content-Type: application/json"
data = "{\"event\":\"$1\"$ovos_error_field}"
OVOS_STATUS
}

load_status_token() {
  ovos_track=''
  for ovos_status_path in "$HOME/.config" "$HOME/.config/ovos-installer"; do
    [ -d "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ] || return 0
  done
  ovos_status_path="$HOME/.config/ovos-installer/status-token"
  if [ -f "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ]; then
    IFS= read -r ovos_track < "$ovos_status_path" || ovos_track=''
  fi
}

report_saved_install() {
  [ -n "${ovos_track:-}" ] || return 0
  for ovos_status_path in "$HOME/.config" "$HOME/.config/ovos-installer"; do
    [ -d "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ] || return 0
  done
  ovos_status_path="$HOME/.config/ovos-installer/status-installed"
  if [ -f "$ovos_status_path" ] && [ ! -L "$ovos_status_path" ]; then
    ovos_status_receipt=''
    IFS= read -r ovos_status_receipt < "$ovos_status_path" || return 0
    [ "$ovos_status_receipt" = "$ovos_track" ] || return 0
    report_status installed
  fi
}

# Shared, embedded terminal helpers. No fetched or user-supplied shell is sourced.
cancel_input() { say cancelled >&2; exit 130; }
restore_tty() {
  # A disconnected terminal must not abort EXIT cleanup or hide the real status.
  [ -z "${ovos_tty:-}" ] || { stty "$ovos_tty" < /dev/tty; } 2>/dev/null || :
}

# Bound external probes on Linux and macOS without requiring GNU timeout. The
# watchdog owns its sleep process, so cancellation leaves no timer behind.
run_bounded() (
  ovos_bound_seconds=$1; shift
  ovos_bound_command=''
  ovos_bound_watchdog=''
  # Invoked by the subshell's EXIT trap.
  # shellcheck disable=SC2329,SC2317
  cleanup_bounded() {
    if [ -n "$ovos_bound_command" ]; then
      kill -KILL "$ovos_bound_command" 2>/dev/null || :
      wait "$ovos_bound_command" 2>/dev/null || :
    fi
    if [ -n "$ovos_bound_watchdog" ]; then
      kill -TERM "$ovos_bound_watchdog" 2>/dev/null || :
      wait "$ovos_bound_watchdog" 2>/dev/null || :
    fi
  }
  trap cleanup_bounded 0
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  # dash redirects background stdin to /dev/null before command redirections.
  # Save the original stream on a separate descriptor before starting the job.
  exec 3<&0
  "$@" <&3 3<&- &
  ovos_bound_command=$!
  exec 3<&-
  (
    ovos_bound_sleep=''
    trap 'if [ -n "$ovos_bound_sleep" ]; then kill "$ovos_bound_sleep" 2>/dev/null || :; wait "$ovos_bound_sleep" 2>/dev/null || :; fi; exit 0' INT TERM HUP
    sleep "$ovos_bound_seconds" & ovos_bound_sleep=$!
    wait "$ovos_bound_sleep" || exit 0
    kill -TERM "$ovos_bound_command" 2>/dev/null || exit 0
    sleep 2 & ovos_bound_sleep=$!
    wait "$ovos_bound_sleep" || exit 0
    kill -KILL "$ovos_bound_command" 2>/dev/null || :
  ) &
  ovos_bound_watchdog=$!
  ovos_bound_status=0
  wait "$ovos_bound_command" || ovos_bound_status=$?
  ovos_bound_command=''
  exit "$ovos_bound_status"
)

# Validate syntax locally; never send a token to a URL just to validate input.
valid_url() {
  case "$1" in http://?*|https://?*) :;; *) return 1;; esac
  case "$1" in *[[:space:][:cntrl:]]*|*'@'*|*'#'*|*\\*) return 1;; esac
  ovos_host=${1#*://}; ovos_host=${ovos_host%%[/?]*}
  case "$ovos_host" in
    '['*']'*)
      ovos_address=${ovos_host#\[}; ovos_address=${ovos_address%%\]*}
      case "$ovos_address" in *:*) :;; *) return 1;; esac
      case "$ovos_address" in ''|*[!0-9a-fA-F:.]*) return 1;; esac
      ovos_port=${ovos_host#*\]}
      case "$ovos_port" in '') return 0;; :*) ovos_port=${ovos_port#:};; *) return 1;; esac;;
    *)
      ovos_address=${ovos_host%%:*}
      case "$ovos_address" in ''|.*|*.|*[!a-zA-Z0-9._-]*) return 1;; esac
      case "$ovos_host" in *:*) ovos_port=${ovos_host#*:};; *) return 0;; esac;;
  esac
  case "$ovos_port" in ''|*[!0-9]*|??????*) return 1;; esac
  # Strip leading zeros before arithmetic, avoiding shell octal interpretation.
  while [ "${ovos_port#0}" != "$ovos_port" ]; do ovos_port=${ovos_port#0}; done
  [ -n "$ovos_port" ] && [ "$ovos_port" -le 65535 ]
}

read_field() {
  # Fixed trusted prompt key and validation kind; answer is never evaluated.
  if [ "$2" = secret ]; then
    ovos_tty=$(stty -g < /dev/tty)
    stty -echo < /dev/tty
  fi
  while :; do
    message "$1" > /dev/tty
    ovos_read_ok=true
    IFS= read -r ovos_answer < /dev/tty || ovos_read_ok=false
    if [ "$2" = secret ]; then
      printf '\n' > /dev/tty
    fi
    [ "$ovos_read_ok" = true ] || cancel_input
    [ "$ovos_answer" != :cancel ] || cancel_input
    case "$ovos_answer" in ''|*[![:space:]]*) :;; *) ovos_answer='';; esac
    if [ -z "$ovos_answer" ]; then say required > /dev/tty; continue; fi
    if [ "$2" = url ] && ! valid_url "$ovos_answer"; then say urlError > /dev/tty; continue; fi
    if [ "$2" = secret ]; then restore_tty; ovos_tty=''; fi
    return 0
  done
}

terminal_choice() {
  message "$1" > /dev/tty
  ovos_answer=''
  IFS= read -r ovos_answer < /dev/tty || return 1
  [ "$ovos_answer" != :cancel ]
}

# These route values are initialized by the validated launcher/checker header.
# shellcheck disable=SC2154
check_services() {
  ovos_services='ovos-messagebus ovos-core'
  if [ "$ovos_experience" = hub ]; then
    ovos_services="$ovos_services hivemind-listener"
  else
    ovos_services="$ovos_services ovos-audio ovos-listener"
  fi
  ovos_health=unknown
  if [ "$ovos_method" = containers ]; then
    # Compose service names come from installed OVOS Docker; do not infer health
    # from unrelated running containers or launch a privileged Docker command.
    if command -v docker >/dev/null 2>&1 && ovos_running=$(run_bounded 10 docker ps --filter label=com.docker.compose.project=ovos --filter status=running --format '{{.Label "com.docker.compose.service"}}' 2>/dev/null); then
      ovos_health=running
      for ovos_service in $ovos_services; do
        ovos_compose_service=$(printf '%s' "$ovos_service" | tr '-' '_')
        printf '%s\n' "$ovos_running" | grep -Fx "$ovos_compose_service" >/dev/null || ovos_health=waiting
      done
    fi
  elif [ "$ovos_device" = mac ]; then
    if command -v launchctl >/dev/null 2>&1; then
      ovos_health=running
      for ovos_service in $ovos_services; do
        ovos_label="com.openvoiceos.$ovos_service"
        [ "$ovos_service" != ovos-core ] || ovos_label=com.ovos.service
        if ! run_bounded 5 launchctl print "gui/$(id -u)/$ovos_label" 2>/dev/null | grep -q 'state = running'; then ovos_health=waiting; fi
      done
    fi
  elif command -v systemctl >/dev/null 2>&1; then
    ovos_health=running
    for ovos_service in $ovos_services; do
      if ! run_bounded 5 systemctl --user is-active --quiet "$ovos_service.service" 2>/dev/null && ! run_bounded 5 systemctl is-active --quiet "$ovos_service.service" 2>/dev/null; then ovos_health=waiting; fi
    done
  fi
  case "$ovos_health" in running) say servicesOk; report_status services_ready;; waiting) say servicesMissing;; *) say servicesUnknown;; esac
}

# Locale/method are initialized by the validated launcher/checker header.
# shellcheck disable=SC2154
sound_check() {
  # The installed virtualenv has the real OVOS configuration and MessageBus API.
  # Limit connection/event waits; a queued utterance never counts as audible.
  if [ "$ovos_method" = containers ]; then
    command -v docker >/dev/null 2>&1 || return 1
  else
    ovos_python="$HOME/.venvs/ovos/bin/python3"
    [ -x "$ovos_python" ] || ovos_python="$HOME/.venvs/ovos/bin/python"
    [ -x "$ovos_python" ] || return 1
  fi
  run_sound_python() {
    if [ "$ovos_method" = containers ]; then run_bounded 35 docker exec -i ovos_audio python3 "$@";
    else run_bounded 35 "$ovos_python" "$@"; fi
  }
  run_sound_python - "$ovos_locale" "$(message audioTest)" <<'OVOS_SOUND'
import sys
import threading
import signal
signal.alarm(30)
client = None
try:
    from ovos_bus_client import MessageBusClient, Message
    client = MessageBusClient()
    ended = threading.Event()
    client.on("recognizer_loop:audio_output_end", lambda _: ended.set())
    client.run_in_thread()
    if not client.connected_event.wait(8):
        raise SystemExit(1)
    client.emit(Message("speak", {"utterance": sys.argv[2], "lang": sys.argv[1]},
                        {"source": "ovos-start-check"}))
    ended.wait(15)
except Exception:
    raise SystemExit(1)
finally:
    if client is not None:
        client.close()
OVOS_SOUND
}

# Experience/skills are initialized by the validated launcher/checker header.
# shellcheck disable=SC2154
check_setup_inner() {
  printf '\n'; say health; check_services
  say resume
  # Expand HOME when the user later pastes the recovery command.
  # shellcheck disable=SC2016
  printf '  sh "$HOME/.config/ovos-installer/check-setup.sh"\n'
  if [ "$ovos_experience" = hub ]; then say hub; say help; return 3; fi
  if ! ( : < /dev/tty ) 2>/dev/null; then say closed; return 3; fi
  while :; do
    terminal_choice checkMenu || { say incomplete; return 3; }
    case "$ovos_answer" in
      2) check_services; continue;;
      1) break;;
      *) say incomplete; return 3;;
    esac
  done
  while :; do
    say audioTest
    if ! sound_check; then say audioFailed; say help; break; fi
    terminal_choice audioQuestion || { say incomplete; return 3; }
    case "$ovos_answer" in
      1) say audioOk; break;;
      2) continue;;
      *) say incomplete; return 3;;
    esac
  done
  say voiceIntro
  if [ "$ovos_skills" = true ]; then say voicePhrase; else say customVoice; fi
  while :; do
    terminal_choice voiceQuestion || { say incomplete; return 3; }
    case "$ovos_answer" in
      1) say voiceOk; report_status voice_ready; return 0;;
      2) say voiceIntro; [ "$ovos_skills" != true ] || say voicePhrase;;
      *) say incomplete; say help; return 3;;
    esac
  done
}

check_setup() {
  if check_setup_inner; then return 0; fi
  report_status needs_attention
  return 3
}

OVOS_RUNTIME
# A private, durable checker survives reboots and never invokes installation.
{
  printf '%s\n' '#!/bin/sh' 'set -eu' 'set +x'
  printf "ovos_locale='%s'\novos_device='%s'\novos_experience='%s'\novos_method='%s'\novos_skills='%s'\n" "$ovos_locale" "$ovos_device" "$ovos_experience" "$ovos_method" "$ovos_skills"
  cat "$ovos_tmp/runtime.sh"
  printf '%s\n' 'load_status_token' 'report_saved_install' 'check_setup'
} > "$ovos_tmp/check-setup.sh"
chmod 700 "$ovos_tmp/check-setup.sh"
say resume
# shellcheck disable=SC2016
printf '  sh "$HOME/.config/ovos-installer/check-setup.sh"\n'
cat > "$ovos_tmp/launch.sh" <<'OVOS_LAUNCH'
#!/bin/sh
set -eu
set +x
umask 077
ovos_source=$1
ovos_home=$2
ovos_scenario=$3
export LOCALE="$4"
ovos_ha=$5
ovos_llm=$6
ovos_tty=''
ovos_locale=$LOCALE
. "$7"
cleanup_launcher() {
  restore_tty
  case "$ovos_source" in */ovos-start.??????/source) cd /; rm -rf "$ovos_source" || :;; esac
}
trap cleanup_launcher 0
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
cd "$ovos_source"
. ./utils/bash_runtime.sh
ovos_bash=$(resolve_bash_runtime 4 || true)
[ -n "$ovos_bash" ] || { say bash >&2; exit 1; }
if [ "$ovos_ha" = true ] || [ "$ovos_llm" != off ]; then
  if ! ( : < /dev/tty ) 2>/dev/null; then say closed >&2; exit 1; fi
  say cancelHint > /dev/tty
fi
if [ "$ovos_ha" = true ]; then
  read_field haUrl url; HOMEASSISTANT_URL=$ovos_answer
  read_field haToken secret; HOMEASSISTANT_API_KEY=$ovos_answer
  export HOMEASSISTANT_URL HOMEASSISTANT_API_KEY
fi
if [ "$ovos_llm" != off ]; then
  if [ "$ovos_llm" = local ]; then say llmLocal > /dev/tty; else say llmOnline > /dev/tty; fi
  read_field llmUrl url; LLM_API_URL=$ovos_answer
  read_field llmModel text; LLM_MODEL=$ovos_answer
  read_field llmKey secret; LLM_API_KEY=$ovos_answer
  case "$LOCALE" in
    en-us) ovos_language='English (US)';; fr-fr) ovos_language='Français';; de-de) ovos_language='Deutsch';;
    es-es) ovos_language='Español';; it-it) ovos_language='Italiano';; nl-nl) ovos_language='Nederlands';;
    pt-pt) ovos_language='Português';; ca-es) ovos_language='Català';; eu-es) ovos_language='Euskara';;
    gl-es) ovos_language='Galego';; hi-in) ovos_language='हिन्दी';; kab-dz) ovos_language='Taqbaylit';;
  esac
  LLM_PERSONA="Respond concisely in $ovos_language for a voice assistant. Use plain spoken language without Markdown or emojis."
  LLM_MAX_TOKENS=300; LLM_TEMPERATURE=0.2; LLM_TOP_P=0.1
  export LLM_API_URL LLM_API_KEY LLM_MODEL LLM_PERSONA LLM_MAX_TOKENS LLM_TEMPERATURE LLM_TOP_P
fi
say installing
# An interrupted older launcher may have left a root-only installer venv.
# Preserve that exact disposable runtime before asking upstream to rebuild it.
# Do not force REUSE_CACHED_ARTIFACTS=false: upstream also clears shared caches.
ovos_venvs="$ovos_home/.venvs"
ovos_installer_runtime="$ovos_venvs/ovos-installer"
for ovos_path in "$ovos_venvs" "$ovos_installer_runtime"; do
  if [ -L "$ovos_path" ] || { [ -e "$ovos_path" ] && [ ! -d "$ovos_path" ]; }; then say unsafeConfig >&2; exit 1; fi
done
if [ -d "$ovos_installer_runtime" ]; then
  ovos_runtime_backup=$(mktemp -d "$ovos_venvs/ovos-installer.backup.XXXXXX")
  if ! mv "$ovos_installer_runtime" "$ovos_runtime_backup/runtime"; then
    rmdir "$ovos_runtime_backup" 2>/dev/null || :
    exit 1
  fi
  say runtimeBackup
  printf '  %s\n' "$ovos_runtime_backup/runtime"
fi
# Recheck after interactive input, before elevated moves.
for ovos_path in "$ovos_home/.config" "$ovos_home/.config/ovos-installer"; do
  if [ ! -d "$ovos_path" ] || [ -L "$ovos_path" ]; then say unsafeConfig >&2; exit 1; fi
done
for ovos_path in "$ovos_home/.config/ovos-installer/scenario.yaml" "$ovos_home/.config/ovos-installer/check-setup.sh" "$ovos_home/.config/ovos-installer/status-token" "$ovos_home/.config/ovos-installer/status-installed"; do
  if [ -L "$ovos_path" ] || { [ -e "$ovos_path" ] && [ ! -f "$ovos_path" ]; }; then say unsafeConfig >&2; exit 1; fi
done
# Clear an earlier receipt before activating any new attempt, including when
# someone explicitly reruns the same tracking token and installation fails.
mv "${10}" "$ovos_home/.config/ovos-installer/status-installed"
mv "$ovos_scenario" "$ovos_home/.config/ovos-installer/scenario.yaml"
mv "$8" "$ovos_home/.config/ovos-installer/check-setup.sh"
mv "$9" "$ovos_home/.config/ovos-installer/status-token"
# sudo may use root's HOME; load only the validated original account's file.
ovos_track=''
IFS= read -r ovos_track < "$ovos_home/.config/ovos-installer/status-token" || ovos_track=''
export RUN_AS="$SUDO_USER"
export RUN_AS_HOME="$ovos_home"
# The upstream bootstrap can hide setup.sh's failure and delete a HOME checkout.
# Execute the resolved setup directly and preserve its exact result.
report_status installing
# Installer dependencies are created as root but also used by Ansible tasks
# running as the regular account. Do not pass our private staging umask to
# that child: it would make venv bin/lib directories root-only. Keep 077 for
# this launcher and its tokens; upstream explicitly protects its own secrets.
(
  # Only a tracked wizard run may request an automatic failure report, and
  # only with our private receipt. Never trust inherited report settings.
  unset OVOS_INSTALLER_REPORT_FD OVOS_INSTALLER_AUTO_REPORT
  exec 3>&-
  if [ -n "$ovos_track" ] && [ "${12}" = "${ovos_source%/source}/error-report" ] && [ -f "${12}" ] && [ ! -L "${12}" ]; then
    exec 3> "${12}"
    OVOS_INSTALLER_REPORT_FD=3
    OVOS_INSTALLER_AUTO_REPORT=1
    export OVOS_INSTALLER_REPORT_FD OVOS_INSTALLER_AUTO_REPORT
  fi
  umask 022
  if [ -n "$ovos_track" ]; then
    export ANSIBLE_CALLBACK_PLUGINS="$ovos_source/.ovos-start-callbacks${ANSIBLE_CALLBACK_PLUGINS:+:$ANSIBLE_CALLBACK_PLUGINS}"
    export ANSIBLE_CALLBACKS_ENABLED="${ANSIBLE_CALLBACKS_ENABLED:-ansible.posix.profile_tasks},ovos_start_progress"
  fi
  exec "$ovos_bash" setup.sh
)
# The pre-created receipt belongs to the regular user and remains mode0600.
# Recheck after the installer ran; failure to persist progress never changes
# an actual zero installer result. A checker only replays a matching receipt.
ovos_receipt_safe=true
for ovos_path in "$ovos_home/.config" "$ovos_home/.config/ovos-installer"; do
  if [ ! -d "$ovos_path" ] || [ -L "$ovos_path" ]; then ovos_receipt_safe=false; fi
done
ovos_receipt="$ovos_home/.config/ovos-installer/status-installed"
if [ -L "$ovos_receipt" ] || { [ -e "$ovos_receipt" ] && [ ! -f "$ovos_receipt" ]; }; then ovos_receipt_safe=false; fi
if [ "$ovos_receipt_safe" = true ]; then mv "${11}" "$ovos_receipt" || :; fi
report_status installed
OVOS_LAUNCH
if sudo sh "$ovos_tmp/launch.sh" "$ovos_source" "$HOME" "$ovos_tmp/scenario.yaml" "$ovos_locale" "$ovos_ha" "$ovos_llm" "$ovos_tmp/runtime.sh" "$ovos_tmp/check-setup.sh" "$ovos_tmp/status-token" "$ovos_tmp/status-installed-empty" "$ovos_tmp/status-installed" "$ovos_error_receipt"; then
  ovos_installed=true
  say installReturned
  # Incomplete verification is not an installer failure. The checker itself
  # returns 3 to distinguish it from a user-confirmed first voice response.
  sh "$ovos_cfg/check-setup.sh" || :
else
  ovos_result=$?
  if [ "$ovos_result" -ne 130 ]; then say installFailed >&2; say help >&2; fi
  exit "$ovos_result"
fi
