import QtQuick 2.0
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.components 3.0 as PlasmaComponents3

import "LocaleFuncs.js" as LocaleFuncs
import "Shared.js" as Shared

LinkRect {
	id: agendaEventItem
	readonly property int eventItemIndex: index
	Layout.fillWidth: true
	implicitHeight: eventColumn.implicitHeight // contents.implicitHeight causes a binding loop
	property bool eventItemInProgress: false
	function checkIfInProgress() {
		if (model.startDateTime && timeModel.currentTime && model.endDateTime) {
			eventItemInProgress = model.startDateTime <= timeModel.currentTime && timeModel.currentTime <= model.endDateTime
		} else {
			eventItemInProgress = false
		}
		// console.log('checkIfInProgress()', model.start, timeModel.currentTime, model.end)
	}
	Connections {
		target: timeModel
		onLoaded: agendaEventItem.checkIfInProgress()
		onMinuteChanged: agendaEventItem.checkIfInProgress()
	}
	Component.onCompleted: {
		agendaEventItem.checkIfInProgress()

		//--- Debugging
		// editEventForm.active = eventItemInProgress && !model.startDateTime
	}

	property alias isEditing: editEventForm.active
	enabled: !isEditing

	readonly property string eventTimestamp: LocaleFuncs.formatEventDuration(model, {
		relativeDate: agendaItemDate,
		clock24h: appletConfig.clock24h,
	})
	readonly property bool isAllDay: eventTimestamp == i18n("All Day") // TODO: Remove string comparison.
	readonly property bool isCondensed: plasmoid.configuration.agendaCondensedAllDayEvent && isAllDay

	RowLayout {
		id: contents
		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 4 * units.devicePixelRatio

		Rectangle {
			implicitWidth: appletConfig.eventIndicatorWidth
			Layout.fillHeight: true
			color: model.backgroundColor || theme.textColor
		}

		ColumnLayout {
			id: eventColumn
			Layout.fillWidth: true
			spacing: 0

			PlasmaComponents3.Label {
				id: eventSummary
				text: {
					if (isCondensed && model.location) {
						return model.summary + " | " + model.location
					} else {
						return model.summary
					}
				}
				color: eventItemInProgress ? inProgressColor : PlasmaCore.ColorScope.textColor
				font.pointSize: -1
				font.pixelSize: appletConfig.agendaFontSize
				font.weight: eventItemInProgress ? inProgressFontWeight : Font.Normal
				visible: !editEventForm.visible
				Layout.fillWidth: true

				// The Following doesn't seem to be applicable anymore (left comment just in case).
				// Wrapping causes reflow, which causes scroll to selection to miss the selected date
				// since it reflows after updateUI/scrollToDate is done.
				wrapMode: Text.Wrap
			}

			PlasmaComponents3.Label {
				id: eventDateTime
				text: {
					if (model.location) {
						return eventTimestamp + " | " + model.location
					} else {
						return eventTimestamp
					}
				}
				color: eventItemInProgress ? inProgressColor : PlasmaCore.ColorScope.textColor
				opacity: eventItemInProgress ? 1 : 0.75
				font.pointSize: -1
				font.pixelSize: appletConfig.agendaFontSize
				font.weight: eventItemInProgress ? inProgressFontWeight : Font.Normal
				visible: !editEventForm.visible && !isCondensed
			}

			Item {
				id: eventDescriptionSpacing
				visible: eventDescription.visible
				implicitHeight: 4 * units.devicePixelRatio
			}

			PlasmaComponents3.Label {
				id: eventDescription
				readonly property bool showProperty: plasmoid.configuration.agendaShowEventDescription && text
				visible: showProperty && !editEventForm.visible
				text: Shared.renderText(model.description)
				color: PlasmaCore.ColorScope.textColor
				opacity: 0.75
				font.pointSize: -1
				font.pixelSize: appletConfig.agendaFontSize
				Layout.fillWidth: true
				wrapMode: Text.Wrap // See warning at eventSummary.wrapMode

				linkColor: PlasmaCore.ColorScope.highlightColor
				onLinkActivated: Qt.openUrlExternally(link)
				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
					cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
				}
			}

			Item {
				id: eventEditorSpacing
				visible: editEventForm.visible
				implicitHeight: 4 * units.devicePixelRatio
			}

			EditEventForm {
				id: editEventForm
				// active: true
			}

			Item {
				id: eventEditorSpacingBelow
				visible: editEventForm.visible
				implicitHeight: 4 * units.devicePixelRatio
			}

			PlasmaComponents.ToolButton {
				id: eventHangoutLink
				readonly property bool showProperty: plasmoid.configuration.agendaShowEventHangoutLink && !!model.hangoutLink
				visible: showProperty && !editEventForm.visible
				text: {
					if (!!model.conferenceData
						&& !!model.conferenceData.conferenceSolution
						&& !!model.conferenceData.conferenceSolution.name
					) {
						return model.conferenceData.conferenceSolution.name
					} else {
						return i18n("Hangout")
					}
				}
				iconSource: plasmoid.file("", "icons/hangouts.svg")
				onClicked: Qt.openUrlExternally(model.hangoutLink)
			}

		} // eventColumn
	}
	
	onLeftClicked: {
		// logger.log('agendaItem.event.leftClicked', model.startDateTime, mouse)
		if (false) {
			var event = events.get(index)
			logger.logJSON("event", event)
			var calendar = eventModel.getCalendar(event.calendarId)
			logger.logJSON("calendar", calendar)
			upcomingEvents.sendEventStartingNotification(model)
		} else {
			// agenda_event_clicked == "browser_viewevent"
			Qt.openUrlExternally(model.htmlLink)
		}
	}

	onLoadContextMenu: {
		var menuItem
		var event = events.get(index)

		menuItem = contextMenu.newMenuItem()
		menuItem.text = i18n("Edit")
		menuItem.icon = "edit-rename"
		menuItem.enabled = event.canEdit
		menuItem.clicked.connect(function() {
			editEventForm.active = !editEventForm.active
			agendaScrollView.positionViewAtEvent(agendaItemIndex, eventItemIndex)
		})
		contextMenu.addMenuItem(menuItem)

		var deleteMenuItem = contextMenu.newSubMenu()
		deleteMenuItem.text = i18n("Delete Event")
		deleteMenuItem.icon = "delete"
		menuItem = contextMenu.newMenuItem(deleteMenuItem)
		menuItem.text = i18n("Confirm Deletion")
		menuItem.icon = "delete"
		menuItem.enabled = event.canEdit
		menuItem.clicked.connect(function() {
			logger.debug('eventModel.deleteEvent', event.calendarId, event.id)
			eventModel.deleteEvent(event.calendarId, event.id)
		})
		deleteMenuItem.enabled = event.canEdit
		deleteMenuItem.subMenu.addMenuItem(menuItem)
		contextMenu.addMenuItem(deleteMenuItem)

		menuItem = contextMenu.newMenuItem()
		menuItem.text = i18n("Edit in browser")
		menuItem.icon = "internet-web-browser"
		menuItem.enabled = !!event.htmlLink
		menuItem.clicked.connect(function() {
			Qt.openUrlExternally(event.htmlLink)
		})
		contextMenu.addMenuItem(menuItem)
	}
}
