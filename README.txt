Beschreibung:
SynOTR ist ein scriptbasiterter Workflow für TV-Aufnahmen von onlineTVrecorder (OTR) auf einer Synology Diskstation (INTEL only), bzw. 
sollte jeder x86-Linuxrechner funktionieren. Es wurde gezielt auf Einfachheit hin entwickelt - wer einen Dateipfad in eine Textdatei 
eintragen kann, sollte hiermit zurecht kommen :-)

Folgende Aufgaben werden automatisch abgearbeitet:
	•	Verschlüsselte .otrkey-Dateien dekodieren
	•	Filme schneiden (Quelle: cutlist.at) / das zugrunde liegende Script (OTRcut) stammt von Daniel Siegmanski (funktioniert 
		aufgrund der mitgelieferten Programme nicht für .mp4-Dateien)
	•	Filme nach eigenen Regeln umbenennen
		Serien werden automatisch erkannt und der Sendungsname umbenannt (Serientitel - S01E01 Episodentitel …) 
		==> VIELEN DANK an Daniel von www.otr-serien.de für das zur Verfügungstellen seiner Website.
		(Es wird 48h lang nach Serieninformationen gesucht, da diese nicht sofort auf otr-serien.de zur Verfügung stehen. Schlägt 
		die Suche dann immer noch fehl, so wird die Normale Umbenennung verwendet).
	•	Konvertieren der .avi’s in native .mp4’s (Mac OS tauglich)

Lässt man sich fertige Aufnahmen per FTP-Push (z.B. Serien) auf die Diskstation übertragen, hat man ohne Zutun fertig geschnittene Aufnahmen.

Das Script stützt sich in großen Teilen auf Erkenntnisse in diesem Thread [klick]. Bitte entschuldigt den quick&dirty Code. Ohne Hilfe hätte 
ich hier gar nichts geschafft. Mein Ziel war es, jetzt eine kompakte Lösung anbieten zu können, die für jedermann (vor allem auch Einsteiger) 
einfach nutzbar sein soll, ohne dass sich jeder in die Materie einarbeiten muss. Es ist also nichts an Skripten zu ändern, noch müssen 
zusätzliche Programme installiert werden (es ist kein IPKG notwendig - wenn es so funktioniert, wie ich mir das vorstelle). Alle 
entsprechenden Programme sind in dem Paket enthalten. Derzeit wird zum schneiden avisplit/avimerge aus Transcode verwendet. Wie die Namen 
schon zeigen, sind sie auf .avi-Dateien beschränkt. Die so erstellten Schnitte sind leider nicht framegenau (die Schnitte sind auf wenige 
Sekunden genau). Das beste (framegenaue) Ergebnis wäre mit Hilfe von avidemux zu erreichen. Es wäre super, wenn jemand dabei helfen könnte, 
avidemux-cli auf der DS zum laufen zu bringen. Entweder man könnte es mit den entsprechenden Abhängigkeiten kompilieren oder gleich 
entsprechend installieren. Die Architektur ist ja kein Problem. Ich hoffe, dass alle mitgelieferten Programme out of the box funktionieren. 

Bitte unterstützt die Seite www.otr-serien.de. Über die Seite lässt es sich auch sehr einfach nach bestimmten Episoden suchen. Ihr habt 
eine ausgestrahlte Serienepisode, die dort nicht automatisch erkannt wurde? Dann gebt doch bei der betroffenen Episode eine Rückmeldung ab.

! ! ! ACHTUNG ! ! ! 
DAS GANZE PAKET IST NOCH BETA. 
BENUTZUNG AUF EIGENE GEFAHR. 
BEI PROBLEMEN ODER FRAGEN BITTE DAS FORUM VERWENDEN. 

Verwendung / Vorbereitung:
	•	Lade das neuste Archiv auf deine Diskstation und entpacke es an deinem gewünschten Zielort
	•	Öffne die enthaltene Datei „Konfiguration.txt“ mit einem Texteditor (z.B. der in DSM 5.1 enthaltene): Hier sind die OTR-Zugangsdaten für das Decodieren, den Ordner mit den .otrkey’s sowie den Zielordner für die fertigen Filme einzutragen. Jeder der vier oben genannten Teilschritte kann aktiviert („on“), oder deaktiviert („off“) werden Des weiteren kann man sich ein Muster für den gewünschten Zieldateinamen zusammenstellen. Jetzt noch die Datei abspeichern (unter Windows beim speichern auf UNIX-Zeilenenden achten!)
	•	Für den automatischen Ablauf ist das Script in den DSM-Aufgabenplaner einzutragen: Kopiere den Pfad zum entpackten Ordner „synOTR" (Filestation > Rechtsklick > Eigenschaften) Erstelle einen neuen Task im Aufgabenplaner (DSM-Systemsteuerung > Aufgabenplaner > Erstellen > Benutzer-definiertes Script) und füge nachstehenden Code ein (ersetze den Pfad hinter „appdir=“ mit deinem Pfad zum Ordner synOTR)  Aufruf inkl. LOG (Pfad anpassen ! ! ! ): appdir=„/volume1/homes/admin/script/synOTR/“ cd $appdir ./synOTR-start.sh >> ./_LOG/synOTR_`date +%Y`-`date +%m`-`date +%d`_`date +%H`-`date +%M`.log 2>&1  oder nur direkter Aufruf des Skripts (Pfad anpassen ! ! ! - dann ohne LOG): „/volume1/homes/admin/script/synOTR/synOTR-start.sh“  erstelle einen gewünschten Zeitplan (z.B. stündlich) (Die Logfiles sind ziemlich groß - z.T. über 50 MB. Sie befinden sich im Unterordner „_LOG“ und können jederzeit gelöscht werden. Läuft alles reibungslos, dann empfiehlt es sich wahrscheinlich im Aufgabenplaner den Scriptaufruf ohne Logfile zu verwenden)



Download:
https://geimist.eu/synOTR/

ToDo:
	•	Metatags für die Serieninformationen in die .mp4’s setzen (AtomicParsley o.ä.)
	•	avidemux-cli als Schnittprogramm verwenden (hat jemand Hilfe …)
	•	es ist mir noch nicht gelungen, für die AAC-Konvertierung in ffmpeg Multihreading zu aktivieren. Alle neuen DSen mit Intel-CPU’s haben ja 4 Threads bzw. 4 Kerne. Könnte man mehrere parallel nutzen, ginge das Ganze natürlich noch etwas flotter.  
	•	ganz toll wäre es auch, wenn jemand eine PHP-Seite / GUI für die Konfigurationsdatei schreiben könnte. So ließe sich das Ganze auch bequem per SPK installieren und verwalten. Des Weiteren wäre so auch eine manuelle Cutlist-Auswahl möglich. 

getestete Modelle:
	•	DS713+ (DSM 5.1)
	•	

LIZENZ:
Dieses Script darf frei verändert und weitergegeben werden. 
Das Script „OTRcut“ sowie die enthaltenen Programme stehen unter deren eigenen Lizenz.

