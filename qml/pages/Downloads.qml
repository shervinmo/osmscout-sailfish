/*
 OSMScout - a Qt backend for libosmscout and libosmscout-map
 Copyright (C) 2016  Lukas Karas

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

import QtQuick 2.2
import Sailfish.Silica 1.0
import QtPositioning 5.2

import harbour.osmscout.map 1.0

import "../custom"

Page {
    id: downloadsPage

    RemorsePopup { id: remorse }

    MapDownloadsModel{
        id:mapDownloadsModel
        onMapDownloadFails: {
            remorse.execute(qsTranslate("message", message), function() { }, 10 * 1000);
        }
    }
    AvailableMapsModel{
        id: availableMapsModel
    }
    InstalledMapsModel{
        id: installedMapsModel
    }

    BusyIndicator {
        id: busyIndicator
        running: availableMapsModel.loading
        size: BusyIndicatorSize.Large
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    SilicaFlickable{
        anchors.fill: parent
        contentHeight: contentColumn.childrenRect.height
        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            anchors.fill: parent

            Column {
                id: downloadsColumn
                width: parent.width
                visible: mapDownloadsModel.rowCount() > 0
                SectionHeader{ text: qsTr("Download Progress") }
                ListView {
                    id: downloadsListView
                    //x: Theme.paddingMedium
                    width: parent.width
                    interactive: false
                    height: contentHeight // binding loop, but how to define?

                    model:mapDownloadsModel

                    delegate: ListItem{
                        Row{
                            spacing: Theme.paddingMedium
                            x: Theme.paddingMedium
                            Image{
                                width:  Theme.fontSizeMedium * 2
                                height: Theme.fontSizeMedium * 2
                                source:"image://theme/icon-m-cloud-download"
                                verticalAlignment: Image.AlignVCenter
                            }

                            Column{
                                Label {
                                    text: mapName
                                }
                                Row {
                                    spacing: Theme.paddingMedium

                                    Label{
                                        text: {
                                            if (model==null)
                                                return "?";
                                            var fraction = model.progressRole;
                                            var percent = (Math.round(fraction * 1000)/10);
                                            return (percent-Math.round(percent)==0) ? percent+".0 %": percent+" %";
                                        }
                                    }
                                    Label{
                                        text: errorString != "" ?
                                                  qsTranslate("message", errorString) :
                                                  (progressDescription!="" ? "(" + progressDescription + ")": "")
                                    }
                                }
                            }
                        }
                    }
                }
                Component.onCompleted: {
                    mapDownloadsModel.modelReset.connect(onModelReset);
                }
                function onModelReset() {
                    console.log("mapDownloadsModel rows: "+mapDownloadsModel.rowCount());
                    downloadsColumn.visible = mapDownloadsModel.rowCount() > 0
                }
            }

            Column {
                id: installedMapsColumn
                width: parent.width
                visible: installedMapsModel.rowCount() > 0
                SectionHeader{ text: qsTr("Downloaded Maps") }
                ListView {
                    id: installedMapsListView
                    //x: Theme.paddingMedium
                    width: parent.width
                    interactive: false
                    height: contentHeight // binding loop, but how to define?
                    clip: true

                    model: installedMapsModel

                    delegate: ListItem{
                        property bool updateAvailable: false

                        Row{
                            spacing: Theme.paddingMedium
                            x: Theme.paddingMedium
                            Image{
                                width:  Theme.fontSizeMedium * 2
                                height: Theme.fontSizeMedium * 2
                                source: updateAvailable ? "image://theme/icon-m-refresh" :  "image://theme/icon-m-other"
                                verticalAlignment: Image.AlignVCenter
                            }

                            Column{
                                Label {
                                    text: name
                                }
                                Row {
                                    spacing: Theme.paddingMedium

                                    Label{
                                        text: directory
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                    }
                                }
                            }
                        }
                        Column{
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.topMargin: Theme.paddingMedium
                            //width: Math.max(sizeLabel.width, dateLabel.width) + Theme.paddingMedium

                            /*
                            Label{
                                id: sizeLabel
                                anchors.right: parent.right
                                visible: !dir
                                text: size
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                            */
                            Label{
                                id: dateLabel
                                anchors.right: parent.right
                                visible: time!=null
                                text: Qt.formatDate(time)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                        }
                        function checkUpdate(){
                            console.log("checking updates for map " + name + " (" + path + ")");
                            if (path.length==0){
                                updateAvailable=false;
                                return;
                            }
                            var latestReleaseTime=availableMapsModel.timeOfMap(path);
                            console.log("map time: " + time + " latestReleaseTime: " + latestReleaseTime +" (" + typeof(latestReleaseTime) + ")");
                            updateAvailable = latestReleaseTime != null && latestReleaseTime > time;
                        }
                        Component.onCompleted: {
                            checkUpdate();
                            availableMapsModel.modelReset.connect(checkUpdate);
                        }
                        onClicked: {
                            //console.log("click for update: " + updateAvailable);
                            if (updateAvailable){
                                var map=availableMapsModel.mapByPath(path);
                                if (map==null){
                                    return;
                                }
                                var item = {
                                    name: map.name,
                                    version: map.version,
                                    description: map.description,
                                    time: map.time,
                                    size: map.size,
                                    map: map
                                };

                                console.log("open map for update: " + item.name + " / "+item.map+ " / " + item.time);

                                pageStack.push(Qt.resolvedUrl("MapDetail.qml"),
                                               {
                                                   availableMapsModel: availableMapsModel,
                                                   //mapIndex: index,
                                                   mapName: item.name,
                                                   mapItem: item,
                                                   downloadsPage: downloadsPage
                                               })
                            }
                        }
                        menu: ContextMenu {
                             MenuItem {
                                 text: qsTr("Delete Map")
                                 onClicked: installedMapsModel.deleteMap(index)
                             }
                         }
                    }
                }
                Component.onCompleted: {
                    installedMapsModel.modelReset.connect(onModelReset);
                }
                function onModelReset() {
                    console.log("installedMapsModel rows: "+installedMapsModel.rowCount());
                    installedMapsColumn.visible = installedMapsModel.rowCount() > 0
                }
            }

            SectionHeader{
                id: downloadMapHeader
                text: qsTr("Download Map")
            }

            Column{
                visible: availableMapsModel.fetchError != ""
                anchors.horizontalCenter: parent.horizontalCenter
                //anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.horizontalPageMargin
                spacing: Theme.paddingLarge
                width: parent.width

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTranslate("message", availableMapsModel.fetchError)
                    font.pixelSize: Theme.fontSizeMedium
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    preferredWidth: Theme.buttonWidthMedium
                    text: qsTr("Refresh")
                    onClicked: {
                        console.log("Reloading...")
                        availableMapsModel.reload();
                    }
                }
            }

            AvailableMapsView{
                id:availableMapListView

                width: parent.width
                height: contentHeight + Theme.paddingMedium // binding loop, but how to define?
                spacing: Theme.paddingMedium

                originModel:availableMapsModel

                onClick: {
                    var index=availableMapsModel.index(row, /*column*/ 0 /* parent */);
                    //console.log("clicked to: "+item.name+" / " + index);
                    if (item.dir){
                        pageStack.push(Qt.resolvedUrl("MapList.qml"),
                                       {
                                           availableMapsModel: availableMapsModel,
                                           rootDirectoryIndex: index,
                                           rootName: item.name,
                                           downloadsPage: downloadsPage
                                       })
                    }else{
                        pageStack.push(Qt.resolvedUrl("MapDetail.qml"),
                                       {
                                           availableMapsModel: availableMapsModel,
                                           //mapIndex: index,
                                           mapName: item.name,
                                           mapItem: item,
                                           downloadsPage: downloadsPage
                                       })
                    }
                }
            }
        }
    }
}
