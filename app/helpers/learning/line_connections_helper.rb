module Learning::LineConnectionsHelper
  def learning_line_qr_svg(url)
    RQRCode::QRCode
      .new(url)
      .as_svg(
        module_size: 5,
        standalone: true,
        use_path: true,
        viewbox: true,
        svg_attributes: {
          class: "learning-line-qr__svg",
          role: "img",
          "aria-label": "LINE連携QRコード"
        }
      )
      .html_safe
  end

  def learning_line_connection_label(connection)
    return "未発行" unless connection
    return "連携済み" if connection.connected?
    return "期限切れ" if connection.token_expired?
    return "QR発行済み" if connection.token_active?

    "未連携"
  end
end
