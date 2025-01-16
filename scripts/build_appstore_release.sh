SCHEME="ping.works"
EXPORT_PATH=".export"
ARCHIVE_PATH="$EXPORT_PATH/ping.works.xcarchive"
DEFAULT_ARCHIVE_PATH="~/Library/Developer/Xcode/Archives"
TEAM_ID="Y4RNS8259T"
API_KEY_ID="76MBRX8466"
API_ISSUER_ID="ccf62fa5-8a1d-4b2d-983e-c3b35e8115fc"

# archive
xcodebuild archive -scheme "$SCHEME" -configuration Release -archivePath "$ARCHIVE_PATH" -quiet

# export archive
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -allowProvisioningUpdates -exportOptionsPlist exportOptions-appstore.plist -exportPath "$EXPORT_PATH"

# upload to App Store
xcrun altool --upload-app -f "$EXPORT_PATH/ping.works.pkg" --type osx --apiKey "$API_KEY_ID" --apiIssuer "$API_ISSUER_ID"
#Check for errors
if [ $? -eq 0 ]; then
    echo "Upload successful"
else
    echo "Upload failed"
    exit 1
fi

# clean up

## move archive to default location
eval DEFAULT_ARCHIVE_PATH=$DEFAULT_ARCHIVE_PATH
final_archive_path="$DEFAULT_ARCHIVE_PATH/$(date '+%Y-%m-%d')/$SCHEME $(date '+%d.%m.%y, %H.%M').xcarchive"
mkdir -p "$(dirname "$final_archive_path")"
mv "$ARCHIVE_PATH" "$final_archive_path"

## delete export path
rm -rf "$EXPORT_PATH"
