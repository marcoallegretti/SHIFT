// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QString>
#include <qqmlregistration.h>

#include <KSharedConfig>

class GameLauncherProvider : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString filterString READ filterString WRITE setFilterString NOTIFY filterStringChanged)
    Q_PROPERTY(QString sourceFilter READ sourceFilter WRITE setSourceFilter NOTIFY sourceFilterChanged)

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
    QString filterString() const;
    void setFilterString(const QString &filter);
    QString sourceFilter() const;
    void setSourceFilter(const QString &source);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void launch(int index);
    Q_INVOKABLE void launchByStorageId(const QString &storageId);
    Q_INVOKABLE QVariantList recentGames(int limit = 5) const;

Q_SIGNALS:
    void countChanged();
    void loadingChanged();
    void filterStringChanged();
    void sourceFilterChanged();
    void gameLaunched(const QString &name);

private:
    struct GameEntry {
        QString name;
        QString icon;
        QString source;
        QString storageId;
        QString launchCommand;
        QString artwork;
        QDateTime lastPlayed;
        bool installed = true;
    };

    void loadDesktopGames();
    void loadSteamGames();
    void loadFlatpakGames();
    void loadLutrisGames();
    void loadHeroicGames();
    void deduplicateGames();
    void loadRecentTimestamps();
    void saveRecentTimestamp(const QString &storageId, const QDateTime &when);
    void applyFilter();
    void launchEntry(GameEntry &entry);

    QList<GameEntry> m_allGames;
    QList<GameEntry> m_games; // filtered view
    QString m_filterString;
    QString m_sourceFilter; // empty = all, or "desktop"/"steam"/"flatpak"
    KSharedConfigPtr m_config;
    bool m_loading = false;
};
