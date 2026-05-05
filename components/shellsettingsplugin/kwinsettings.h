/*
 *  SPDX-FileCopyrightText: 2025 Florian RICHER <florian.richer@protonmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <KConfigGroup>
#include <KConfigWatcher>
#include <KSharedConfig>
#include <qobject.h>
#include <qqmlintegration.h>

class KWinSettings : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(KWinSettings)
    QML_SINGLETON

    Q_PROPERTY(bool doubleTapWakeup READ doubleTapWakeup WRITE setDoubleTapWakeup NOTIFY doubleTapWakeupChanged)
    Q_PROPERTY(int screenEdgeTouchTarget READ screenEdgeTouchTarget WRITE setScreenEdgeTouchTarget NOTIFY screenEdgeTouchTargetChanged)
    Q_PROPERTY(QString titleButtonsOnLeft READ titleButtonsOnLeft NOTIFY titleButtonsChanged)
    Q_PROPERTY(QString titleButtonsOnRight READ titleButtonsOnRight NOTIFY titleButtonsChanged)

public:
    KWinSettings(QObject *parent = nullptr);

    /**
     * Whether Double Tap to Wakeup is enabled.
     */
    bool doubleTapWakeup() const;

    /**
     * Set whether Double Tap to Wakeup is enabled.
     *
     * @param enabled
     */
    void setDoubleTapWakeup(bool enabled);

    /**
     * Get the screen edge touch target value.
     */
    int screenEdgeTouchTarget() const;

    /**
     * Set the screen edge touch target value.
     *
     * @param target
     */
    void setScreenEdgeTouchTarget(int target);

    /**
     * Configured KWin titlebar buttons on the left side.
     */
    QString titleButtonsOnLeft() const;

    /**
     * Configured KWin titlebar buttons on the right side.
     */
    QString titleButtonsOnRight() const;

Q_SIGNALS:
    void doubleTapWakeupChanged();
    void screenEdgeTouchTargetChanged();
    void titleButtonsChanged();

private:
    KConfigWatcher::Ptr m_configWatcher;
    KSharedConfig::Ptr m_config;
    KSharedConfig::Ptr m_overlayConfig;
};
