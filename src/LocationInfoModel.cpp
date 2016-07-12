
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

#include "LocationInfoModel.h"

LocationInfoModel::LocationInfoModel(): 
ready(false), setup(false)
{
    DBThread *dbThread = DBThread::GetInstance();
    
    qRegisterMetaType<osmscout::GeoCoord>("osmscout::GeoCoord");
    qRegisterMetaType<osmscout::LocationDescription>("osmscout::LocationDescription");
    
    connect(dbThread, SIGNAL(InitialisationFinished(const DatabaseLoadedResponse&)), 
            this, SLOT(dbInitialized(const DatabaseLoadedResponse&)),
            Qt::QueuedConnection);
    
    connect(this, SIGNAL(locationDescriptionRequested(const osmscout::GeoCoord)), 
            dbThread, SLOT(requestLocationDescription(const osmscout::GeoCoord)),
            Qt::QueuedConnection);
    
    connect(dbThread, SIGNAL(locationDescription(const osmscout::GeoCoord, const osmscout::LocationDescription)), 
            this, SLOT(onLocationDescription(const osmscout::GeoCoord, const osmscout::LocationDescription)),
            Qt::QueuedConnection);
    
}

void LocationInfoModel::setLocation(const double lat, const double lon)
{
    location = osmscout::GeoCoord(lat, lon);
    setup = true;
    ready = false;

    emit readyChange(ready);
    emit locationDescriptionRequested(location);
}

void LocationInfoModel::dbInitialized(const DatabaseLoadedResponse&)
{
    if (setup){
        emit locationDescriptionRequested(location);
    }
}

Qt::ItemFlags LocationInfoModel::flags(const QModelIndex &index) const
{
    if(!index.isValid()) {
        return Qt::ItemIsEnabled;
    }

    return QAbstractListModel::flags(index) | Qt::ItemIsEnabled | Qt::ItemIsSelectable;
}

QHash<int, QByteArray> LocationInfoModel::roleNames() const
{
    QHash<int, QByteArray> roles=QAbstractListModel::roleNames();

    roles[LabelRole]="label";
    roles[TitleRole]="title";
    roles[AddressRole]="address";
    roles[InPlaceRole]="inPlace";
    roles[DistanceRole]="distance";
    roles[BearingRole]="bearing";

    return roles;
}

QVariant LocationInfoModel::data(const QModelIndex &index, int role) const
{
    qDebug() << "Get data" << index.row() << " role: " << role << " (label: " << LabelRole<< ")";
    
    if (!ready){
        return QVariant();
    }
    if(index.row() < 0 || index.row() >= 1) {
        return QVariant();
    }
    
    //osmscout::LocationCoordDescriptionRef coordDescription=description.GetCoordDescription();
    osmscout::LocationAtPlaceDescriptionRef atAddressDescription=description.GetAtAddressDescription();
    
    if (atAddressDescription) {
        osmscout::Place place = atAddressDescription->GetPlace();
        
        osmscout::POIRef poiRef = place.GetPOI();
        osmscout::LocationRef locRef = place.GetLocation();
        osmscout::AddressRef addrRef = place.GetAddress();
        osmscout::AdminRegionRef regionRef = place.GetAdminRegion();
        
        QStringList descriptionParts;
        if (poiRef){
            descriptionParts << QString::fromStdString(poiRef->name);
        }
        if (locRef){
            descriptionParts << QString::fromStdString(locRef->name);
        }
        if (addrRef){
            descriptionParts << QString::fromStdString(addrRef->name);
        }
        if (regionRef){
            descriptionParts << QString::fromStdString(regionRef->name);
        }
        QString address;
        for (int i = 1; i < descriptionParts.size(); i++){
            address += descriptionParts.at(i);
            if (i < descriptionParts.size() -1){
                address += ", ";
            }
        }
        
        
        switch (role) {
        case Qt::DisplayRole:
        case LabelRole:
            qDebug() << "Label";
            return QString::fromStdString(place.GetDisplayString());
        case TitleRole:
            if (!descriptionParts.isEmpty()){
                qDebug() << "Title " << descriptionParts.front();
                return descriptionParts.front();
            }
            return "";
        case AddressRole:
            qDebug() << "Address " << address;
            return address;
        case InPlaceRole:
            return atAddressDescription->IsAtPlace();
        case DistanceRole:
            return atAddressDescription->GetDistance();
        case BearingRole:
            qDebug() << "Bearing";
            return QString::fromStdString(osmscout::BearingDisplayString(atAddressDescription->GetBearing()));
        default:
            break;
        }
    }
    return QVariant();    
}

void LocationInfoModel::onLocationDescription(const osmscout::GeoCoord location, 
                                              const osmscout::LocationDescription description)
{
    if (location != this->location){
        return; // not our request
    }
    
    beginResetModel();
    this->description = description;
    ready = true;
    emit readyChange(ready);    
    endResetModel();
    
    // just debug
    osmscout::LocationAtPlaceDescriptionRef atAddressDescription=description.GetAtAddressDescription();    
    if (atAddressDescription) {
        
        osmscout::Place place = atAddressDescription->GetPlace();
        
        if (atAddressDescription->IsAtPlace()){
            qDebug() << "Place " << QString::fromStdString(location.GetDisplayText()) << " description: " 
                     << QString::fromStdString(place.GetDisplayString()); 
        }else{
            qDebug() << "Place " << QString::fromStdString(location.GetDisplayText()) << " description: " 
                     << atAddressDescription->GetDistance() << " m " 
                     << QString::fromStdString(osmscout::BearingDisplayString(atAddressDescription->GetBearing())) << " from "
                     << QString::fromStdString(place.GetDisplayString());
        }
    }else{
        qWarning() << "No place description found for " << QString::fromStdString(location.GetDisplayText()) << "";
    }
    // end of debug    
}

double LocationInfoModel::distance(double lat1, double lon1, 
                                    double lat2, double lon2)
{
    

    return osmscout::GetEllipsoidalDistance(
            osmscout::GeoCoord(lat1, lon1),
            osmscout::GeoCoord(lat2, lon2)) * 1000;
}

QString LocationInfoModel::bearing(double lat1, double lon1, 
                                   double lat2, double lon2)
{
    return QString::fromStdString(
            osmscout::BearingDisplayString(
                osmscout::GetSphericalBearingInitial(
                    osmscout::GeoCoord(lat1, lon1),
                    osmscout::GeoCoord(lat2, lon2))));
}
