import GoogleMobileAds
import UIKit

class NewsArticleNativeAdFactory: FLTNativeAdFactory {
    
    func createNativeAd(_ nativeAd: GADNativeAd, customOptions: [AnyHashable : Any]? = nil) -> GADNativeAdView? {
        
        // Create the native ad view programmatically to match the immersive news article design
        let adView = GADNativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = UIColor.black
        
        // 1. Media View (Background Image - Full Screen)
        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        adView.addSubview(mediaView)
        
        // 2. Gradient Overlays (Top & Bottom)
        
        // Top Gradient
        let topGradientLayer = CAGradientLayer()
        topGradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.7).cgColor,
            UIColor.clear.cgColor
        ]
        topGradientLayer.locations = [0.0, 1.0]
        let topGradientView = UIView()
        topGradientView.translatesAutoresizingMaskIntoConstraints = false
        topGradientView.isUserInteractionEnabled = false
        topGradientView.layer.addSublayer(topGradientLayer)
        adView.addSubview(topGradientView)
        
        // Bottom Gradient
        let bottomGradientLayer = CAGradientLayer()
        bottomGradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.black.withAlphaComponent(0.85).cgColor
        ]
        bottomGradientLayer.locations = [0.0, 0.4, 1.0]
        let bottomGradientView = UIView()
        bottomGradientView.translatesAutoresizingMaskIntoConstraints = false
        bottomGradientView.isUserInteractionEnabled = false
        bottomGradientView.layer.addSublayer(bottomGradientLayer)
        adView.addSubview(bottomGradientView)
        
        // 3. Content Container (Overlay)
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(contentContainer)
        
        // Sponsored Badge (Top Left)
        let badgeContainer = UIView()
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.95)
        badgeContainer.layer.cornerRadius = 20
        contentContainer.addSubview(badgeContainer)
        
        let sponsoredLabel = UILabel()
        sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
        sponsoredLabel.font = UIFont.systemFont(ofSize: 11, weight: .black)
        sponsoredLabel.textColor = UIColor.black
        sponsoredLabel.text = "SPONSORED"
        sponsoredLabel.letterSpacing = 1.5
        badgeContainer.addSubview(sponsoredLabel)
        
        // Headline Label
        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
        headlineLabel.textColor = UIColor.white
        headlineLabel.numberOfLines = 4
        headlineLabel.text = nativeAd.headline
        // Add shadow
        headlineLabel.layer.shadowColor = UIColor.black.cgColor
        headlineLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        headlineLabel.layer.shadowOpacity = 0.5
        headlineLabel.layer.shadowRadius = 4
        contentContainer.addSubview(headlineLabel)
        
        // Body Label
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        bodyLabel.textColor = UIColor(white: 1.0, alpha: 0.95)
        bodyLabel.numberOfLines = 3
        bodyLabel.text = nativeAd.body
        bodyLabel.layer.shadowColor = UIColor.black.cgColor
        bodyLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        bodyLabel.layer.shadowOpacity = 0.5
        bodyLabel.layer.shadowRadius = 2
        contentContainer.addSubview(bodyLabel)
        
        // Action Bar (Bottom)
        let actionBar = UIView()
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        actionBar.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        actionBar.layer.cornerRadius = 16
        actionBar.layer.borderWidth = 1.5
        actionBar.layer.borderColor = UIColor(white: 1.0, alpha: 0.3).cgColor
        contentContainer.addSubview(actionBar)
        
        // Icon View
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = UIColor.clear
        iconView.contentMode = .scaleAspectFit
        if let icon = nativeAd.icon {
            iconView.image = icon.image
        }
        actionBar.addSubview(iconView)
        
        // Advertiser Label
        let advertiserLabel = UILabel()
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        advertiserLabel.textColor = UIColor.white
        advertiserLabel.text = nativeAd.advertiser ?? "Sponsored"
        actionBar.addSubview(advertiserLabel)
        
        // CTA Button (Visual only, acts as part of ad view tap)
        let ctaButton = UIButton(type: .custom)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
        ctaButton.layer.cornerRadius = 10
        ctaButton.setTitle(nativeAd.callToAction ?? "Open", for: .normal)
        ctaButton.setTitleColor(UIColor.white, for: .normal)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        ctaButton.isUserInteractionEnabled = false // Let the whole ad view handle clicks
        actionBar.addSubview(ctaButton)
        
        // --- Constraints ---
        NSLayoutConstraint.activate([
            // Media View (Fill Screen)
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
            
            // Gradients
            topGradientView.topAnchor.constraint(equalTo: adView.topAnchor),
            topGradientView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            topGradientView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            topGradientView.heightAnchor.constraint(equalTo: adView.heightAnchor, multiplier: 0.3),
            
            bottomGradientView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
            bottomGradientView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            bottomGradientView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            bottomGradientView.heightAnchor.constraint(equalTo: adView.heightAnchor, multiplier: 0.5),
            
            // Content Container (SafeArea)
            contentContainer.topAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -20),
            contentContainer.bottomAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Badge
            badgeContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 20),
            badgeContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            badgeContainer.heightAnchor.constraint(equalToConstant: 30),
            
            sponsoredLabel.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            sponsoredLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            sponsoredLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 12),
            sponsoredLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -12),
            
            // Action Bar (Bottom)
            actionBar.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -8),
            actionBar.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            actionBar.heightAnchor.constraint(equalToConstant: 56),
            
            // Body (Above Action Bar)
            bodyLabel.bottomAnchor.constraint(equalTo: actionBar.topAnchor, constant: -24),
            bodyLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            
            // Headline (Above Body)
            headlineLabel.bottomAnchor.constraint(equalTo: bodyLabel.topAnchor, constant: -16),
            headlineLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            headlineLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            
            // Icon in Action Bar
            iconView.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Advertiser Label
            advertiserLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            advertiserLabel.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            advertiserLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -8),
            
            // CTA Button
            ctaButton.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor, constant: -12),
            ctaButton.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            ctaButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Handle layout changes for gradient layers
        adView.layoutSubviews() // Force layout to get frames
        topGradientLayer.frame = topGradientView.bounds
        bottomGradientLayer.frame = bottomGradientView.bounds
        
        // Register views
        adView.mediaView = mediaView
        adView.headlineView = headlineLabel
        adView.bodyView = bodyLabel
        adView.iconView = iconView
        adView.advertiserView = advertiserLabel
        adView.callToActionView = ctaButton
        
        adView.nativeAd = nativeAd
        
        return adView
    }
}

extension UILabel {
    var letterSpacing: CGFloat {
        get {
            return 0
        }
        set {
            let attributedString: NSMutableAttributedString
            if let currentAttrString = attributedText {
                attributedString = NSMutableAttributedString(attributedString: currentAttrString)
            } else {
                attributedString = NSMutableAttributedString(string: text ?? "")
                setTitleAttributes(attributedString)
            }
            
            attributedString.addAttribute(
                NSAttributedString.Key.kern,
                value: newValue,
                range: NSRange(location: 0, length: attributedString.length)
            )
            attributedText = attributedString
        }
    }
    
    private func setTitleAttributes(_ attributedString: NSMutableAttributedString) {
        attributedString.addAttribute(NSAttributedString.Key.font, value: font, range: NSRange(location: 0, length: attributedString.length))
        attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributedString.length))
    }
}