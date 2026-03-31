package com.plantmanager.service;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import com.google.zxing.qrcode.QRCodeWriter;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@ApplicationScoped
public class QrCodeService {

    @ConfigProperty(name = "app.backend.base-url", defaultValue = "http://localhost:8080")
    String backendBaseUrl;

    public byte[] generatePlantQrCode(UUID plantId, int size) throws WriterException, IOException {
        String url = backendBaseUrl + "/api/v1/public/plant/" + plantId;
        return generateQrCode(url, size);
    }

    public byte[] generateQrCode(String content, int size) throws WriterException, IOException {
        QRCodeWriter writer = new QRCodeWriter();
        Map<EncodeHintType, Object> hints = Map.of(
                EncodeHintType.MARGIN, 4,
                EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M,
                EncodeHintType.CHARACTER_SET, "UTF-8"
        );

        BitMatrix matrix = writer.encode(content, BarcodeFormat.QR_CODE, size, size, hints);

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        MatrixToImageWriter.writeToStream(matrix, "PNG", out);
        return out.toByteArray();
    }
}
