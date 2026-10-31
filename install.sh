#!/bin/bash

# Installing Dependencies
echo "Installing Dependencies..."
sudo apt update
sudo apt install -y git wget openjdk-21-jre

# Detect Java 21 / 17 (Java 22+ like Java 25 breaks loader.jar bytecode patching)
JAVA_BIN=""
for candidate in \
    "/usr/lib/jvm/java-21-openjdk-amd64/bin/java" \
    "/usr/lib/jvm/java-21-openjdk-arm64/bin/java" \
    "/usr/lib/jvm/java-21-openjdk/bin/java" \
    "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" \
    "/usr/lib/jvm/java-17-openjdk-arm64/bin/java" \
    "/usr/lib/jvm/java-17-openjdk/bin/java"; do
    if [ -x "$candidate" ]; then
        JAVA_BIN="$candidate"
        break
    fi
done

if [ -z "$JAVA_BIN" ]; then
    JAVA_BIN="$(which java)"
else
    # Automatically switch system-wide java to Java 21/17 so all tools & loader use it
    echo "Setting default system Java to: $JAVA_BIN"
    sudo update-alternatives --set java "$JAVA_BIN" 2>/dev/null || update-alternatives --set java "$JAVA_BIN" 2>/dev/null || true
fi

echo "Using Java runtime: $JAVA_BIN"

# Cloning if not already in project folder
if [ ! -f "loader.jar" ]; then
    if [ ! -d "Burpsuite-Professional" ]; then
        git clone https://github.com/IshantSomani/Burpsuite-Professional.git
        cd Burpsuite-Professional || exit 1
    else
        cd Burpsuite-Professional || exit 1
    fi
fi

INSTALL_DIR="$(pwd)"
version=2026
JAR_FILE="burpsuite_pro_v${version}.jar"

# Download Burpsuite Professional
if [ ! -s "$JAR_FILE" ]; then
    echo "Downloading Burp Suite Professional Latest..."
    wget -O "$JAR_FILE" "https://github.com/IshantSomani/Burpsuite-Professional/releases/download/burpsuite-pro/$JAR_FILE" 2>/dev/null

    # Fallback to official PortSwigger download if GitHub release asset does not exist (< 10MB)
    if [ ! -s "$JAR_FILE" ] || [ $(stat -c%s "$JAR_FILE" 2>/dev/null || stat -f%z "$JAR_FILE" 2>/dev/null || echo 0) -lt 10485760 ]; then
        echo "Release asset not found on GitHub, downloading directly from PortSwigger..."
        rm -f "$JAR_FILE"
        wget -O "$JAR_FILE" "https://portswigger.net/burp/releases/download?product=pro&type=Jar"
    fi
else
    echo "$JAR_FILE already exists, skipping download."
fi

# Set proper ownership and permissions
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR"
fi
chmod -R 755 "$INSTALL_DIR"

# Execute Key Generator using Java 21
echo "Starting Key loader.jar..."
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    sudo -u "$SUDO_USER" "$JAVA_BIN" -jar "$INSTALL_DIR/loader.jar" &
else
    ("$JAVA_BIN" -jar "$INSTALL_DIR/loader.jar") &
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

# Detect Java 21 / 17 (Java 22+ like Java 25 breaks loader.jar bytecode patching)
JAVA_BIN=""
for candidate in \
    "/usr/lib/jvm/java-21-openjdk-amd64/bin/java" \
    "/usr/lib/jvm/java-21-openjdk-arm64/bin/java" \
    "/usr/lib/jvm/java-21-openjdk/bin/java" \
    "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" \
    "/usr/lib/jvm/java-17-openjdk-arm64/bin/java" \
    "/usr/lib/jvm/java-17-openjdk/bin/java"; do
    if [ -x "$candidate" ]; then
        JAVA_BIN="$candidate"
        break
    fi
done

if [ -z "$JAVA_BIN" ]; then
    JAVA_BIN="$(which java)"
fi

"$JAVA_BIN" --add-opens=java.desktop/javax.swing=ALL-UNNAMED \
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

# Create Desktop Application Entry for Kali Linux Application Menu
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

echo "Installation complete!"

# Ensure ~/.java and ~/.BurpSuite belong to the real user so license saves permanently
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    mkdir -p "/home/$SUDO_USER/.java" "/home/$SUDO_USER/.BurpSuite"
    chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.java" "/home/$SUDO_USER/.BurpSuite" 2>/dev/null || true

    # If root has any existing activated license, sync it to user
    if [ -d "/root/.java" ]; then
        cp -rn /root/.java/* "/home/$SUDO_USER/.java/" 2>/dev/null || true
        chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.java" 2>/dev/null || true
    fi

    echo "Starting Burp Suite Professional as $SUDO_USER..."
    sudo -u "$SUDO_USER" ./burpsuitepro &
else
    echo "Starting Burp Suite Professional..."
    (./burpsuitepro) &
fi
