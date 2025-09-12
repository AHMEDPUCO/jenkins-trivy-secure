FROM nginx:1.25-alpine  #este es un comentario

COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
