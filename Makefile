OUT := out

bench: 
	odin build . -o:speed -out:${OUT}

clean: 
	rm ${OUT}
