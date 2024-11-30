#from PIL import Image
import numpy as np
import cv2
import pandas as pd
import torch
from torch.utils.data import DataLoader,Dataset
from transformers import TrOCRProcessor, VisionEncoderDecoderModel
from torch.optim import AdamW
from datasets import load_dataset
from tqdm import tqdm
import os

train_data=pd.read_csv("DoctorHandwrittenPrescription_Dataset//Training//training_labels.csv")

val_data=pd.read_csv("DoctorHandwrittenPrescription_Dataset//Validation//validation_labels.csv")

train_images,train_labels=[],[]
train_img_path='./DoctorHandwrittenPrescription_Dataset//Training//training_words'
for i in range(len(train_data)):
    image_path=str(train_img_path+"//"+train_data['IMAGE'][i])
    img = cv2.imread(image_path)
    train_images.append(img)
    train_labels.append(train_data['MEDICINE_NAME'][i])

val_images,val_labels=[],[]
val_img_path='./DoctorHandwrittenPrescription_Dataset//Validation//validation_words'
for i in range(len(val_data)):
    img = cv2.imread(val_img_path+"//"+val_data['IMAGE'][i])
    val_images.append(img)
    val_labels.append(val_data['MEDICINE_NAME'][i])



processor = TrOCRProcessor.from_pretrained('microsoft/trocr-base-handwritten')

# Function to process images and labels
def preprocess_function(images_list,labels_list):
    images = [img for img in images_list]  # Replace with image field name
    texts = [label for label in labels_list]    # Replace with text field name
    pixel_values = processor(images, return_tensors="pt").pixel_values
    labels = processor.tokenizer(texts, return_tensors="pt", padding=True).input_ids
    return {'pixel_values': pixel_values, 'labels': labels}

class CustomDataset(Dataset):
    def __init__(self, images,labels_list, processor):
        self.images = images
        self.labels_list=labels_list
        self.processor = processor

    def __len__(self):
        return len(self.images)

    def __getitem__(self, idx):
        # item = self.dataset[idx]
        image = self.images[idx]  # Adjust the field name if necessary
        text = self.labels_list[idx]
        
        # Process the input image and target text
        pixel_values = self.processor(image, return_tensors="pt").pixel_values.squeeze()  # Image tensor
        labels = self.processor.tokenizer(text, return_tensors="pt",padding="max_length",    # Pad all sequences to `max_length`
    truncation=True,         # Truncate sequences longer than `max_length`
    max_length=32).input_ids.squeeze()  # Text token ids
        # labels = label_tokens[text]
        
        return {"pixel_values": pixel_values, "labels": labels}


# Create dataset objects

train_data = CustomDataset(train_images,train_labels, processor)
val_data = CustomDataset(val_images,val_labels, processor)

# DataLoader
train_loader = DataLoader(train_data, batch_size=8, shuffle=False)
val_loader = DataLoader(val_data, batch_size=8)

#if(os.listdir('./trained_trocr_model')):
# model = VisionEncoderDecoderModel.from_pretrained('./trained_trocr_model')
#else:
model = VisionEncoderDecoderModel.from_pretrained('microsoft/trocr-base-handwritten', cache_dir="models_cache")

# Adjust model configuration
model.config.decoder_start_token_id = processor.tokenizer.cls_token_id
model.config.pad_token_id = processor.tokenizer.pad_token_id
model.config.vocab_size = model.config.decoder.vocab_size

# Set up optimizer
optimizer = AdamW(model.parameters(), lr=1e-7)

# Use GPU if available
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
# torch.cuda.set_device(4)
# device=torch.cuda.current_device()
model.to(device)

# Training loop
num_epochs = 20  # Adjust the number of epochs

for epoch in range(num_epochs):
    model.train()
    train_loss = 0.0
    
    for batch in tqdm(train_loader):
        # Move data to device
        pixel_values = batch['pixel_values'].to(device)
        labels = batch['labels'].to(device)

        # Forward pass
        outputs = model(pixel_values=pixel_values, labels=labels)
        loss = outputs.loss

        # Backward pass and optimization
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        train_loss += loss.item()

    avg_train_loss = train_loss / len(train_loader)
    print(f"Epoch {epoch + 1} - Training Loss: {avg_train_loss:.4f}")

    # Validation (optional)
    model.eval()
    val_loss = 0.0
    with torch.no_grad():
        for batch in val_loader:
            pixel_values = batch['pixel_values'].to(device)
            labels = batch['labels'].to(device)
            
            outputs = model(pixel_values=pixel_values, labels=labels)
            loss = outputs.loss
            val_loss += loss.item()

    avg_val_loss = val_loss / len(val_loader)
    print(f"Epoch {epoch + 1} - Validation Loss: {avg_val_loss:.4f}")
# Save the model and processor
model.save_pretrained('./trained_trocr_model')
processor.save_pretrained('./trained_trocr_model')