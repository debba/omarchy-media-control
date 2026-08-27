import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// GNOME-style media indicator for the Omarchy bar.
//
// Bar: a single play/pause glyph, shown only while something is playing
// (or paused, unless `hideWhenPaused` is set). Left click opens the panel,
// right click toggles playback, wheel skips tracks.
//
// Panel: app name + icon, artwork, title/artist, prev/play/next, seek bar
// with elapsed/total time, and a source picker when several players exist.
//
// Playback state comes from Omarchy's built-in omarchy.media service, so
// OSD feedback, source cycling and keyboard media keys stay consistent.
BarWidget {
  id: root
  moduleName: "debba.media-control"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media") ?? null
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hideWhenPaused: settings && settings.hideWhenPaused === true
  readonly property int panelWidth: settings && settings.panelWidth > 0 ? settings.panelWidth : 340

  readonly property bool hasMedia: activePlayer !== null && !!(activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool isPlaying: activePlayer !== null && activePlayer.isPlaying
  readonly property bool shouldShow: hasMedia && (isPlaying || !hideWhenPaused || popupOpen)

  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  // Resolve the player's .desktop entry so we can show the proper app name
  // and icon (e.g. Zen reports desktopEntry "zen" whose icon is "zen-browser").
  readonly property var appEntry: activePlayer && activePlayer.desktopEntry ? DesktopEntries.byId(activePlayer.desktopEntry) : null
  readonly property string appName: appEntry && appEntry.name ? appEntry.name
    : activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media") : "Media"
  readonly property string appIcon: {
    if (appEntry && appEntry.icon) {
      var themed = Quickshell.iconPath(appEntry.icon, true)
      if (themed) return themed
    }
    if (activePlayer && activePlayer.desktopEntry) return Quickshell.iconPath(activePlayer.desktopEntry, true) || ""
    return ""
  }

  readonly property bool hasLength: !!activePlayer && activePlayer.lengthSupported && activePlayer.length > 0
  readonly property bool hasPosition: !!activePlayer && activePlayer.positionSupported
  readonly property real trackLength: {
    var p = activePlayer
    return p && p.lengthSupported && p.length > 0 ? p.length : 0
  }
  readonly property real trackPosition: {
    var p = activePlayer
    if (!p || !p.positionSupported) return 0
    var pos = p.position
    var len = p.lengthSupported && p.length > 0 ? p.length : 0
    return len > 0 ? Math.min(pos, len) : pos
  }

  property bool popupOpen: false
  function close() { popupOpen = false }

  onShouldShowChanged: if (!shouldShow) popupOpen = false

  // omarchy-shell debba.media-control toggle|open|close|playPause|next|previous
  IpcHandler {
    target: "debba.media-control"
    function toggle(): void { if (root.hasMedia) root.popupOpen = !root.popupOpen }
    function open(): void { if (root.hasMedia) root.popupOpen = true }
    function close(): void { root.popupOpen = false }
    function playPause(): void { root.act("playPause") }
    function next(): void { root.act("next") }
    function previous(): void { root.act("previous") }
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) seconds = 0
    var total = Math.floor(seconds)
    var h = Math.floor(total / 3600)
    var m = Math.floor((total % 3600) / 60)
    var s = total % 60
    var mm = h > 0 && m < 10 ? "0" + m : "" + m
    var ss = s < 10 ? "0" + s : "" + s
    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
  }

  function act(action) {
    if (!mediaService || !activePlayer) return
    mediaService.runAction(action, false, mediaService.playerKey(activePlayer))
  }

  visible: shouldShow
  implicitWidth: shouldShow ? glyph.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Text {
    id: glyph
    anchors.centerIn: parent
    text: root.isPlaying ? "󰐊" : "󰏤"
    color: root.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.body
    Behavior on color {
      enabled: !root.bar || root.bar.foregroundAnimationEnabled
      ColorAnimation { duration: 160 }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else if (mouse.button === Qt.RightButton) root.act("playPause")
      else if (mouse.button === Qt.MiddleButton) root.act("next")
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0) root.act("previous")
      else if (wheel.angleDelta.y < 0) root.act("next")
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.title + (root.artist ? " — " + root.artist : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // MPRIS only pushes position on seeks/track changes; nudge the binding once
  // a second while the panel is open so the seek bar advances smoothly.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.isPlaying && root.hasPosition
    triggeredOnStart: true
    onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      // ── App header ────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: Style.space(18)
          height: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            source: root.appIcon
            visible: root.appIcon !== ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize: Qt.size(width * 2, height * 2)
          }

          Text {
            anchors.centerIn: parent
            visible: root.appIcon === ""
            text: "󰝚"
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.appName
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          width: parent.width - Style.space(26)
        }
      }

      // ── Artwork + track + controls ────────────────────────────────
      Row {
        id: mainRow
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          id: art
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.artUrl
            visible: root.artUrl !== "" && status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          id: trackInfo
          width: mainRow.width - art.width - controls.width - mainRow.spacing * 2
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }

        Row {
          id: controls
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒮"
            foreground: root.bar.foreground
            enabled: root.activePlayer && root.activePlayer.canGoPrevious
            onClicked: root.act("previous")
          }

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.isPlaying ? "󰏤" : "󰐊"
            iconSize: Style.font.iconLarge
            // Nerd Font play/pause glyphs sit low in their line box.
            iconOffsetY: -iconSize * 0.08
            foreground: root.bar.foreground
            enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
            onClicked: root.act("playPause")
          }

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒭"
            foreground: root.bar.foreground
            enabled: root.activePlayer && root.activePlayer.canGoNext
            onClicked: root.act("next")
          }
        }
      }

      // ── Seek bar ──────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(10)
        visible: root.hasLength

        Text {
          id: elapsed
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(seek.dragging ? seek.liveValue : root.trackPosition)
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: Style.space(40)
        }

        PanelSlider {
          id: seek
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - elapsed.width - total.width - parent.spacing * 2
          bar: root.bar
          minimum: 0
          maximum: Math.max(1, root.trackLength)
          step: 1
          value: root.trackPosition
          enabled: root.activePlayer && root.activePlayer.canSeek
          opacity: enabled ? 1.0 : 0.6
          onReleased: function(v) {
            if (root.activePlayer && root.activePlayer.canSeek) root.activePlayer.position = v
          }
        }

        Text {
          id: total
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(root.trackLength)
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: Style.space(40)
          horizontalAlignment: Text.AlignRight
        }
      }

      // ── Source picker (only with several players) ─────────────────
      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData
            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceApp: player ? (player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceTrack: player ? [player.trackTitle, player.trackArtist].filter(Boolean).join(" · ") : ""

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰐊" : "󰏤"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: sourceRow.sourceApp
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: sourceRow.sourceTrack
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
