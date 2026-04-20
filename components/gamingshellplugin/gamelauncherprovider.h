// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <qqmlregistration.h>

class GameLauncherProvider : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit GameLauncherProvider(QObject *parent = nullptr);

    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconRole,
        SourceRole, // "desktop", "steam", "flatpak"
        StorageIdRole, // .desktop file name or launch URI
        LaunchCommandRole,
        ArtworkRole, // path to banner/grid image (empty if none)
        InstalledRole,
    };
    Q_ENUM(Roles)

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool loading() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void launch(int index);

Q_SIGNALS:
    void countChanged();
    void loadingChanged();
    void gameLaunched(const QString &name);

private:
    struct GameEntry {
        QString name;
        QString icon;
        QString source;
        QString storageId;
        QString launchCommand;
        QString artwork;
        bool installed = true;
    };

    void loadDesktopGames();
    void loadSteamGames();
    void loadFlatpakGames();

    QList<GameEntry> m_games;
    bool m_loading = false;
};
