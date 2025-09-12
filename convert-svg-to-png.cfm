<cfscript>
// Convert SVG to PNG using Batik - based on https://dev.lucee.org/t/demo-rendering-svg-using-batik-with-lucee-6-2/14951

    // Input and output paths
    svgPath = expandPath("./source/images/lucee_lcov_icon.svg");
    pngPath = expandPath("./source/images/lucee_lcov_icon.png");
    
    systemOutput("Converting SVG to PNG...", true);
    systemOutput("Input: " & svgPath, true);
    systemOutput("Output: " & pngPath, true);
    
    // Check if SVG file exists
    if (!fileExists(svgPath)) {
        throw(message="SVG file not found: " & svgPath);
    }
    
    // Create SVG renderer component with Maven dependencies
    svgRenderer = new component javasettings='{
        maven: [
            "org.apache.xmlgraphics:batik-transcoder:1.18",
            "org.apache.xmlgraphics:batik-codec:1.18"
        ]
    }' {
        import java.io.FileInputStream;
        import java.io.FileOutputStream;
        import java.io.File;
        import org.apache.batik.transcoder.TranscoderInput;
        import org.apache.batik.transcoder.TranscoderOutput;
        import org.apache.batik.transcoder.image.PNGTranscoder;
        
        public function render(required string svgPath, required string outputPath) {
            var transcoder = new PNGTranscoder();
            var input = new TranscoderInput(new FileInputStream(new File(svgPath)));
            var outputStream = new FileOutputStream(outputPath);
            try {
                var output = new TranscoderOutput(outputStream);
                transcoder.transcode(input, output);
                outputStream.flush();
            } catch(e) {
                rethrow;
            } finally {
                outputStream.close();
            }
        }
    };
    
    // Perform the conversion
    svgRenderer.render(svgPath, pngPath);
    
    systemOutput("✓ Successfully converted SVG to PNG: " & pngPath, true);
    
    // Verify the PNG was created
    if (fileExists(pngPath)) {
        fileInfo = getFileInfo(pngPath);
        systemOutput("PNG file size: " & fileInfo.size & " bytes", true);
    }
</cfscript>