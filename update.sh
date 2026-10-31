#!/bin/bash

# Remove old files
echo "Removing Old Launcher Files..."
sudo rm -f /bin/burpsuitepro /usr/local/bin/burpsuitepro

# Installing Dependencies
echo "Installing Dependencies..."
sudo apt update
sudo apt install -y git wget openjdk-21-jre

# Cloning or Pulling latest
if [ ! -f "loader.jar" ]; then
    if [ ! -d "Burpsuite-Professional" ]; then
        git clone https://github.com/IshantSomani/Burpsuite-Professional.git
        cd Burpsuite-Professional || exit 1
    else
        cd Burpsuite-Professional || exit 1
        git pull
    fi
else
    git pull
fi

INSTALL_DIR="$(pwd)"
version=2026
JAR_FILE="burpsuite_pro_v${version}.jar"

# Download Burpsuite Professional
echo "Downloading Burp Suite Professional Latest..."
rm -f "$JAR_FILE"
wget -O "$JAR_FILE" "https://github.com/IshantSomani/Burpsuite-Professional/releases/download/burpsuite-pro/$JAR_FILE" 2>/dev/null

if [ ! -s "$JAR_FILE" ] || [ $(stat -c%s "$JAR_FILE" 2>/dev/null || stat -f%z "$JAR_FILE" 2>/dev/null || echo 0) -lt 10485760 ]; then
    echo "Release asset not found on GitHub, downloading directly from PortSwigger..."
    rm -f "$JAR_FILE"
    wget -O "$JAR_FILE" "https://portswigger.net/burp/releases/download?product=pro&type=Jar"
fi

# Set proper ownership and permissions
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR"
fi
chmod -R 755 "$INSTALL_DIR"

# Execute Key Generator
echo "Starting Key loader.jar..."
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    sudo -u "$SUDO_USER" java -jar "$INSTALL_DIR/loader.jar" &
else
    (java -jar "$INSTALL_DIR/loader.jar") &
fi

# Execute Burpsuite Professional Wrapper
echo "Configuring Burpsuite Professional launcher..."
cat << 'EOF' > burpsuitepro
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/loader.jar" ]; then
    SCRIPT_DIR="INSTALL_DIR_PLACEHOLDER"
fi

JAR_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "burpsuite_pro_v*.jar" | head -n 1)
if [ -z "$JAR_FILE" ]; then
    JAR_FILE="$SCRIPT_DIR/burpsuite_pro_v2026.jar"
fi

java --add-opens=java.desktop/javax.swing=ALL-UNNAMED \
     --add-opens=java.base/java.lang=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED \
     -javaagent:"$SCRIPT_DIR/loader.jar" \
     -noverify \
     -jar "$JAR_FILE" "$@" &
EOF

sed -i "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" burpsuitepro
chmod +x burpsuitepro
sudo cp burpsuitepro /usr/local/bin/burpsuitepro
sudo cp burpsuitepro /bin/burpsuitepro 2>/dev/null || true

# Update Desktop Application Entry
cat << EOF | sudo tee /usr/share/applications/burpsuitepro.desktop > /dev/null
[Desktop Entry]
Name=Burp Suite Professional
GenericName=Web Application Security Testing
Comment=Burp Suite Professional Edition
Exec=/usr/local/bin/burpsuitepro
Icon=/usr/share/icons/hicolor/scalable/apps/burpsuite.svg
Terminal=false
Type=Application
Categories=03-webapp-analysis;03-01-web-application-proxies;Development;Security;
StartupWMClass=burp-StartBurp
EOF

echo "Update complete! Starting Burp Suite Professional..."
(./burpsuitepro)
