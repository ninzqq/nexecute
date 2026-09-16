package com.jndevworks.nexecute

internal data class NexecuteWidgetTheme(
    val headerBackground: Int,
    val gridBackground: Int,
    val columnBackground: Int,
    val primaryText: Int,
    val secondaryText: Int,
    val mutedText: Int,
    val accent: Int,
) {
    companion object {
        fun fromId(id: String?): NexecuteWidgetTheme = when (id) {
            "cyberpunk" -> NexecuteWidgetTheme(
                headerBackground = 0xFF120A25.toInt(),
                gridBackground = 0xFF080510.toInt(),
                columnBackground = 0xFF100B20.toInt(),
                primaryText = 0xFFF5EEFF.toInt(),
                secondaryText = 0xFFFF3BD4.toInt(),
                mutedText = 0xFF8F849F.toInt(),
                accent = 0xFF00E7F0.toInt(),
            )
            "cyberpunkMega" -> NexecuteWidgetTheme(
                headerBackground = 0xFF15121F.toInt(),
                gridBackground = 0xFF080A10.toInt(),
                columnBackground = 0xFF12101A.toInt(),
                primaryText = 0xFF00D7E5.toInt(),
                secondaryText = 0xFFD83ADB.toInt(),
                mutedText = 0xFF777284.toInt(),
                accent = 0xFF00D7E5.toInt(),
            )
            "forest" -> NexecuteWidgetTheme(
                headerBackground = 0xFF0B1913.toInt(),
                gridBackground = 0xFF07110D.toInt(),
                columnBackground = 0xFF0E1D17.toInt(),
                primaryText = 0xFFE4F0E8.toInt(),
                secondaryText = 0xFFE1B866.toInt(),
                mutedText = 0xFF83958A.toInt(),
                accent = 0xFF72D6A0.toInt(),
            )
            "neutral" -> NexecuteWidgetTheme(
                headerBackground = 0xFF121416.toInt(),
                gridBackground = 0xFF0D0F11.toInt(),
                columnBackground = 0xFF15171A.toInt(),
                primaryText = 0xFFE2E4E7.toInt(),
                secondaryText = 0xFFF0A45D.toInt(),
                mutedText = 0xFF858A91.toInt(),
                accent = 0xFFAEB7C4.toInt(),
            )
            else -> NexecuteWidgetTheme(
                headerBackground = 0xFF0D1727.toInt(),
                gridBackground = 0xFF080D17.toInt(),
                columnBackground = 0xFF101827.toInt(),
                primaryText = 0xFFE8EEF8.toInt(),
                secondaryText = 0xFF6AD7E5.toInt(),
                mutedText = 0xFF7D899B.toInt(),
                accent = 0xFF78A9FF.toInt(),
            )
        }
    }
}
